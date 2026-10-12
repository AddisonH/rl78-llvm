//===- RL78.cpp ----------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "ABIInfoImpl.h"
#include "TargetInfo.h"

using namespace clang;
using namespace clang::CodeGen;

//===----------------------------------------------------------------------===//
// RL78 ABI Implementation.
//===----------------------------------------------------------------------===//

namespace {
class RL78ABIInfo : public DefaultABIInfo {
public:
  RL78ABIInfo(CodeGenTypes &CGT) : DefaultABIInfo(CGT) {}

private:
  ABIArgInfo classifyReturnType(QualType RetTy) const;
  ABIArgInfo classifyArgumentType(QualType ArgTy, bool IsVarArg) const;
  void computeInfo(CGFunctionInfo &FI) const override;
  RValue EmitVAArg(CodeGenFunction &CGF, Address VAListAddr, QualType Ty,
                   AggValueSlot Slot) const override;
};
} // end anonymous namespace


static ABIArgInfo coerceStructToIntArray(QualType Ty,
                                          ASTContext &Context,
                                          llvm::LLVMContext &LLVMContext, bool IsVarArg = false) {
  // Alignment and Size are measured in bits.
  const uint64_t Size = Context.getTypeSize(Ty);
  const uint64_t Alignment = IsVarArg ? 16 : Context.getTypeAlign(Ty);
  llvm::Type *IntType = llvm::Type::getIntNTy(LLVMContext, Alignment);
  const uint64_t NumElements = (Size + Alignment - 1) / Alignment;
  return ABIArgInfo::getDirect(llvm::ArrayType::get(IntType, NumElements));
}

ABIArgInfo RL78ABIInfo::classifyReturnType(QualType Ty) const {
  //if its void, ignore  
  if (Ty->isVoidType())
    return ABIArgInfo::getIgnore();

  // Get size in Bits.
  uint64_t Size = getContext().getTypeSize(Ty);
  // If it doesn't fit in 4 bytes place it on the stack.
  if (Size > 32) {
    // Indirect pointers are in the default address space, as in 17.
    return getNaturalAlignIndirect(
        Ty, getContext().getTargetAddressSpace(LangAS::Default), true);
  } else {
     if (isAggregateTypeForABI(Ty)) {
      return coerceStructToIntArray(Ty,getContext(), getVMContext());
     } else {
      return ABIArgInfo::getDirect();
     }
  }  
}

ABIArgInfo RL78ABIInfo::classifyArgumentType(QualType ArgTy, bool IsVarArg) const {
  //const RecordType *RT = ArgTy->getAs<RecordType>();
  //TODO 
  //promote near pointers to far pointer
  //handle void*?

  if (isAggregateTypeForABI(ArgTy)) {
    // Records with non-trivial destructors/copy-constructors should not be
    // passed by value.
    if (CGCXXABI::RecordArgABI RAA = getRecordArgABI(ArgTy, getCXXABI()))
      return getNaturalAlignIndirect(
          ArgTy, getContext().getTargetAddressSpace(LangAS::Default),
          RAA == CGCXXABI::RAA_DirectInMemory);
    return coerceStructToIntArray(ArgTy, getContext(), getVMContext(), IsVarArg);
  } else {
    return ABIArgInfo::getDirect();
  }
}

void RL78ABIInfo::computeInfo(CGFunctionInfo &FI) const {
  if (!getCXXABI().classifyReturnType(FI))
    FI.getReturnInfo() = classifyReturnType(FI.getReturnType());

 size_t ArgIndex = 0;
 for (auto &Arg : FI.arguments()) {
    Arg.info = classifyArgumentType(Arg.type, FI.getNumRequiredArgs() <= ArgIndex);
	ArgIndex++;
 }
}

RValue RL78ABIInfo::EmitVAArg(CodeGenFunction &CGF, Address VAListAddr,
                              QualType Ty, AggValueSlot Slot) const {

  // Emit va_arg using the common void* representation,
  // where arguments are simply emitted in an array of slots on the stack.
  // All arguments are passed directly, using 2 byte slots.
  // We don't allow greater than 2 byte alignment.

  auto TypeInfo = getContext().getTypeInfoInChars(Ty);

  return emitVoidPtrVAArg(CGF, VAListAddr, Ty, /*Indirect*/ false, TypeInfo,
                          CharUnits::fromQuantity(2),
                          /*AllowHigherAlign*/ false, Slot);
}

#include "llvm/IR/Constants.h"

namespace {
class RL78TargetCodeGenInfo : public TargetCodeGenInfo {
 
  bool isFarAddressSpace(unsigned int AS, CodeGen::CodeGenModule &CGM) const {
    return AS == CGM.getContext().getTargetAddressSpace(LangAS::__far_code) ||
           AS == CGM.getContext().getTargetAddressSpace(LangAS::__far_data);
  }

  bool isNullOrUndef(const llvm::Constant *C) const {
  // Check that the constant isn't all zeros or undefs.
  if (C->isNullValue() || isa<llvm::UndefValue>(C))
    return true;
  if (!isa<llvm::ConstantAggregate>(C))
    return false;
  for (auto Operand : C->operand_values()) {
    if (!isNullOrUndef(cast<llvm::Constant>(Operand)))
      return false;
  }
  return true;
}

  bool isBss(const VarDecl *VD, const llvm::GlobalVariable *GV) const {
    return !VD->hasInit() && !GV->isConstant();
  }

  bool isData(const VarDecl *VD, const llvm::GlobalVariable *GV) const {
    return VD->hasInit() && !GV->isConstant();
  }

public:
  RL78TargetCodeGenInfo(CodeGen::CodeGenTypes &CGT)
      : TargetCodeGenInfo(std::make_unique<RL78ABIInfo>(CGT)) {}

  void setTargetAttributes(const Decl *D, llvm::GlobalValue *GV,
                           CodeGen::CodeGenModule &CGM) const override {
    bool isFar = isFarAddressSpace(GV->getAddressSpace(), CGM);

    if (const auto *FD = dyn_cast_or_null<FunctionDecl>(D)) {
      auto *Fn = cast<llvm::Function>(GV);
      if (const auto *Attr = FD->getAttr<RL78InterruptAttr>()) {
        std::string Specs = std::to_string(Attr->getSpecs());
        for (unsigned Vect : Attr->vects()) {
          Specs.append("Vect_");
          Specs.append(std::to_string(Vect));
        }
        Fn->addFnAttr("interrupt", Specs);
        Fn->addFnAttr("disable-tail-calls", "true");
        // marking the interrupt handlers as used ensures that they aren't discarded by LTO
        if (!D->hasAttr<UsedAttr>())
          const_cast<Decl *>(D)->addAttr(UsedAttr::CreateImplicit(CGM.getContext()));
      }

      if (const auto *Attr = FD->getAttr<RL78BRKInterruptAttr>()) {
        std::string Specs = std::to_string(Attr->getSpecs());
        Fn->addFnAttr("brk_interrupt", Specs);
        Fn->addFnAttr("disable-tail-calls", "true");
      }

      if (const auto *Attr = FD->getAttr<RL78CalltAttr>()) {
        Fn->addFnAttr("callt");
      }

    }

    if (const auto *VD = dyn_cast_or_null<VarDecl>(D)) {
      auto *Var = cast<llvm::GlobalVariable>(GV);

      // With -mfar-data, the default address space is far
      if (CGM.getLangOpts().RenesasRL78DataModel && 
          GV->getAddressSpace() == CGM.getContext().getTargetAddressSpace(LangAS::Default))
          isFar = true; 
      
      if (VD->hasAttr<RL78SaddrAttr>()) {
        if(GV->getLinkage() == llvm::GlobalVariable::CommonLinkage)
          GV->setLinkage(llvm::GlobalVariable::ExternalLinkage);
        Var->addAttribute("saddr");
      }
    }
  }
};
} // namespace

std::unique_ptr<TargetCodeGenInfo>
CodeGen::createRL78TargetCodeGenInfo(CodeGenModule &CGM) {
    return std::make_unique<RL78TargetCodeGenInfo>(CGM.getTypes());
}
