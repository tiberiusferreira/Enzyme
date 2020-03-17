; RUN: %opt < %s %loadEnzyme -enzyme -enzyme_preopt=false -mem2reg -sroa -simplifycfg -instcombine -adce -S | FileCheck %s
; This test ensures that the index of gep doesn't lead to a collision where it is mistaken as both a double and a i64 pointer
; - in other words, not crashing makes this a success!
define void @sub(i64* %inp, i64 %idx) {
entry:
  %gep = getelementptr inbounds i64, i64* %inp, i64 %idx
  %cst = bitcast i64* %gep to double*
  store double 0.000000e+00, double* %cst, !tbaa !6
  ret void
}

define void @foo(i64* %inp, i64* %out) {
entry:
  store i64 3, i64* %inp, !tbaa !3
  call void @sub(i64* %inp, i64 1)
  ret void
}

define void @call(i64* %inp, i64* %inpp, i64* %out, i64* %outp) {
entry:
  call void (i8*, ...) @__enzyme_autodiff(i8* bitcast (void (i64*, i64*)* @foo to i8*), metadata !"diffe_dup", i64* %inp, i64* %inpp, metadata !"diffe_dup", i64* %out, i64* %outp)
  ret void
}

declare dso_local void @__enzyme_autodiff(i8*, ...)

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang version 7.1.0 "}
!2 = !{!3, !3, i64 0}
!3 = !{!"long long", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}
!6 = !{!7, !7, i64 0}
!7 = !{!"double", !4, i64 0}

; CHECK: define internal {} @diffefoo(i64* %inp, i64* %"inp'", i64* %out, i64* %"out'") {
; CHECK-NEXT: entry:
; CHECK-NEXT:   store i64 3, i64* %"inp'", align 4
; CHECK-NEXT:   store i64 3, i64* %inp, align 4, !tbaa !6
; CHECK-NEXT:   %0 = call {} @diffesub(i64* %inp, i64* %"inp'", i64 1)
; CHECK-NEXT:   ret {} undef
; CHECK-NEXT: }

; CHECK: define internal {} @diffesub(i64* %inp, i64* %"inp'", i64 %idx) {
; CHECK-NEXT: entry:
; CHECK-NEXT:   %"gep'ipge" = getelementptr inbounds i64, i64* %"inp'", i64 %idx
; CHECK-NEXT:   %gep = getelementptr inbounds i64, i64* %inp, i64 %idx
; CHECK-NEXT:   %cst = bitcast i64* %gep to double*
; CHECK-NEXT:   store double 0.000000e+00, double* %cst, align 8, !tbaa !2
; CHECK-NEXT:   %"cst'ipc" = bitcast i64* %"gep'ipge" to double*
; CHECK-NEXT:   store double 0.000000e+00, double* %"cst'ipc", align 8
; CHECK-NEXT:   ret {} undef
; CHECK-NEXT: }
