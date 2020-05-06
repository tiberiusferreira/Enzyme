/*
 * Utils.h
 *
 * Copyright (C) 2019 William S. Moses (enzyme@wsmoses.com) - All Rights Reserved
 *
 * For commercial use of this code please contact the author(s) above.
 *
 * For research use of the code please use the following citation.
 *
 * \misc{mosesenzyme,
    author = {William S. Moses, Tim Kaler},
    title = {Enzyme: LLVM Automatic Differentiation},
    year = {2019},
    howpublished = {\url{https://github.com/wsmoses/Enzyme/}},
    note = {commit xxxxxxx}
 */

#ifndef ENZYME_UTILS_H
#define ENZYME_UTILS_H

#include "llvm/ADT/SmallPtrSet.h"

#include "llvm/IR/Function.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Operator.h"
#include "llvm/IR/Type.h"

#include "llvm/IR/Function.h"
#include "llvm/IR/IntrinsicInst.h"

#include "llvm/Support/Casting.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/IR/ValueMap.h"

#include <set>

static inline llvm::FastMathFlags getFast() {
    llvm::FastMathFlags f;
    f.set();
    return f;
}

template<typename T>
static inline T max(T a, T b) {
  if (a > b) return a;
  return b;
}

template<typename T>
static inline std::string to_string(const std::set<T>& us) {
    std::string s = "{";
    for(const auto& y : us) s += std::to_string(y) + ",";
    return s + "}";
}


template<typename T, typename N>
static inline void dumpMap(const llvm::ValueMap<T, N> &o, std::function<bool(const llvm::Value*)> shouldPrint = [](T){ return true; }) {
    llvm::errs() << "<begin dump>\n";
    for(auto a : o) {
      if (shouldPrint(a.first))
        llvm::errs() << "key=" << *a.first << " val=" << *a.second << "\n";
    }
    llvm::errs() << "</end dump>\n";
}

template<typename T>
static inline void dumpSet(const llvm::SmallPtrSetImpl<T*> &o) {
    llvm::errs() << "<begin dump>\n";
    for(auto a : o) llvm::errs() << *a << "\n";
    llvm::errs() << "</end dump>\n";
}

static inline llvm::Instruction *getNextNonDebugInstructionOrNull(llvm::Instruction* Z) {
   for (llvm::Instruction *I = Z->getNextNode(); I; I = I->getNextNode())
     if (!llvm::isa<llvm::DbgInfoIntrinsic>(I))
       return I;
   return nullptr;
}

static inline llvm::Instruction *getNextNonDebugInstruction(llvm::Instruction* Z) {
   auto z = getNextNonDebugInstructionOrNull(Z);
   if (z) return z;
   llvm::errs() << *Z->getParent() << "\n";
   llvm::errs() << *Z << "\n";
   llvm_unreachable("No valid subsequent non debug instruction");
   exit(1);
   return nullptr;
}

static inline bool hasMetadata(const llvm::GlobalObject* O, llvm::StringRef kind) {
    return O->getMetadata(kind) != nullptr;
}

static inline bool hasMetadata(const llvm::Instruction* O, llvm::StringRef kind) {
    return O->getMetadata(kind) != nullptr;
}

enum class ReturnType {
    ArgsWithReturn,
    ArgsWithTwoReturns,
    Args,
    TapeAndReturn,
    TapeAndTwoReturns,
    Tape,
};

enum class DIFFE_TYPE {
  OUT_DIFF=0, // add differential to output struct
  DUP_ARG=1,  // duplicate the argument and store differential inside
  CONSTANT=2  // no differential
};

static inline std::string tostring(DIFFE_TYPE t) {
    switch(t) {
      case DIFFE_TYPE::OUT_DIFF:
        return "OUT_DIFF";
      case DIFFE_TYPE::CONSTANT:
        return "CONSTANT";
      case DIFFE_TYPE::DUP_ARG:
        return "DUP_ARG";
      default:
        assert(0 && "illegal diffetype");
        return "";
    }
}

#include <set>

//note this doesn't handle recursive types!
static inline DIFFE_TYPE whatType(llvm::Type* arg, std::set<llvm::Type*> seen = {}) {
  assert(arg);
  if (seen.find(arg) != seen.end()) return DIFFE_TYPE::CONSTANT;
  seen.insert(arg);

  if (arg->isPointerTy()) {
    switch(whatType(llvm::cast<llvm::PointerType>(arg)->getElementType(), seen)) {
      case DIFFE_TYPE::OUT_DIFF:
        return DIFFE_TYPE::DUP_ARG;
      case DIFFE_TYPE::CONSTANT:
        return DIFFE_TYPE::CONSTANT;
      case DIFFE_TYPE::DUP_ARG:
        return DIFFE_TYPE::DUP_ARG;
    }
    assert(arg);
    llvm::errs() << "arg: " << *arg << "\n";
    assert(0 && "Cannot handle type0");
    return DIFFE_TYPE::CONSTANT;
  } else if (arg->isArrayTy()) {
    return whatType(llvm::cast<llvm::ArrayType>(arg)->getElementType(), seen);
  } else if (arg->isStructTy()) {
    auto st = llvm::cast<llvm::StructType>(arg);
    if (st->getNumElements() == 0) return DIFFE_TYPE::CONSTANT;

    auto ty = DIFFE_TYPE::CONSTANT;
    for(unsigned i=0; i<st->getNumElements(); i++) {
      switch(whatType(st->getElementType(i), seen)) {
        case DIFFE_TYPE::OUT_DIFF:
              switch(ty) {
                case DIFFE_TYPE::OUT_DIFF:
                case DIFFE_TYPE::CONSTANT:
                  ty = DIFFE_TYPE::OUT_DIFF;
                  break;
                case DIFFE_TYPE::DUP_ARG:
                  ty = DIFFE_TYPE::DUP_ARG;
                  return ty;
              }
        case DIFFE_TYPE::CONSTANT:
              switch(ty) {
                case DIFFE_TYPE::OUT_DIFF:
                  ty = DIFFE_TYPE::OUT_DIFF;
                  break;
                case DIFFE_TYPE::CONSTANT:
                  break;
                case DIFFE_TYPE::DUP_ARG:
                  ty = DIFFE_TYPE::DUP_ARG;
                  return ty;
              }
        case DIFFE_TYPE::DUP_ARG:
            return DIFFE_TYPE::DUP_ARG;
      }
    }

    return ty;
  } else if (arg->isIntOrIntVectorTy() || arg->isFunctionTy ()) {
    return DIFFE_TYPE::CONSTANT;
  } else if  (arg->isFPOrFPVectorTy()) {
    return DIFFE_TYPE::OUT_DIFF;
  } else {
    assert(arg);
    llvm::errs() << "arg: " << *arg << "\n";
    assert(0 && "Cannot handle type");
    return DIFFE_TYPE::CONSTANT;
  }
}

static inline bool isReturned(llvm::Instruction *inst) {
	for (const auto &a:inst->users()) {
		if(llvm::isa<llvm::ReturnInst>(a))
			return true;
	}
	return false;
}

static inline llvm::Type* FloatToIntTy(llvm::Type* T) {
    assert(T->isFPOrFPVectorTy());
    if (auto ty = llvm::dyn_cast<llvm::VectorType>(T)) {
        return llvm::VectorType::get(FloatToIntTy(ty->getElementType()), ty->getNumElements());
    }
    if (T->isHalfTy()) return llvm::IntegerType::get(T->getContext(), 16);
    if (T->isFloatTy()) return llvm::IntegerType::get(T->getContext(), 32);
    if (T->isDoubleTy()) return llvm::IntegerType::get(T->getContext(), 64);
    assert(0 && "unknown floating point type");
    return nullptr;
}

static inline llvm::Type* IntToFloatTy(llvm::Type* T) {
    assert(T->isIntOrIntVectorTy());
    if (auto ty = llvm::dyn_cast<llvm::VectorType>(T)) {
        return llvm::VectorType::get(IntToFloatTy(ty->getElementType()), ty->getNumElements());
    }
    if (auto ty = llvm::dyn_cast<llvm::IntegerType>(T)) {
        switch(ty->getBitWidth()) {
            case 16: return llvm::Type::getHalfTy(T->getContext());
            case 32: return llvm::Type::getFloatTy(T->getContext());
            case 64: return llvm::Type::getDoubleTy(T->getContext());
        }
    }
    assert(0 && "unknown int to floating point type");
    return nullptr;
}

static inline bool isCertainMallocOrFree(llvm::Function* called) {
    if (called == nullptr) return false;
    if (called->getName() == "printf" || called->getName() == "puts" || called->getName() == "malloc" || called->getName() == "_Znwm" || called->getName() == "_ZdlPv" || called->getName() == "_ZdlPvm" || called->getName() == "free") return true;
    switch(called->getIntrinsicID()) {
        case llvm::Intrinsic::dbg_declare:
        case llvm::Intrinsic::dbg_value:
            #if LLVM_VERSION_MAJOR > 6
        case llvm::Intrinsic::dbg_label:
            #endif
        case llvm::Intrinsic::dbg_addr:
        case llvm::Intrinsic::lifetime_start:
        case llvm::Intrinsic::lifetime_end:
                return true;
            default:
                break;
    }

    return false;
}

static inline bool isCertainPrintOrFree(llvm::Function* called) {
    if (called == nullptr) return false;

    if (called->getName() == "printf" || called->getName() == "puts" || called->getName() == "_ZdlPv" || called->getName() == "_ZdlPvm" || called->getName() == "free") return true;
    switch(called->getIntrinsicID()) {
        case llvm::Intrinsic::dbg_declare:
        case llvm::Intrinsic::dbg_value:
            #if LLVM_VERSION_MAJOR > 6
        case llvm::Intrinsic::dbg_label:
            #endif
        case llvm::Intrinsic::dbg_addr:
        case llvm::Intrinsic::lifetime_start:
        case llvm::Intrinsic::lifetime_end:
                return true;
            default:
                break;
    }
    return false;
}

static inline bool isCertainPrintMallocOrFree(llvm::Function* called) {
    if (called == nullptr) return false;

    if (called->getName() == "printf" || called->getName() == "puts" || called->getName() == "malloc" || called->getName() == "_Znwm" || called->getName() == "_ZdlPv" || called->getName() == "_ZdlPvm" || called->getName() == "free") return true;
    switch(called->getIntrinsicID()) {
        case llvm::Intrinsic::dbg_declare:
        case llvm::Intrinsic::dbg_value:
            #if LLVM_VERSION_MAJOR > 6
        case llvm::Intrinsic::dbg_label:
            #endif
        case llvm::Intrinsic::dbg_addr:
        case llvm::Intrinsic::lifetime_start:
        case llvm::Intrinsic::lifetime_end:
                return true;
            default:
                break;
    }
    return false;
}

//! Create function for type that performs the derivative memcpy on floating point memory
llvm::Function* getOrInsertDifferentialFloatMemcpy(llvm::Module& M, llvm::PointerType* T, unsigned dstalign, unsigned srcalign);

//! Create function for type that performs the derivative memmove on floating point memory
llvm::Function* getOrInsertDifferentialFloatMemmove(llvm::Module& M, llvm::PointerType* T, unsigned dstalign, unsigned srcalign);

#endif
