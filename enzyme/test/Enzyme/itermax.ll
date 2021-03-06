; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -inline -mem2reg -correlated-propagation -adce -instcombine -instsimplify -early-cse-memssa -simplifycfg -correlated-propagation -adce -jump-threading -instsimplify -early-cse -simplifycfg -S | FileCheck %s

; #include <math.h>
; #include <stdio.h>
;
; static double max(double x, double y) {
;     return (x > y) ? x : y;
; }
;
; __attribute__((noinline))
; static double iterA(double *__restrict x, size_t n) {
;   double A = x[0];
;   for(int i=0; i<=n; i++) {
;     A = max(A, x[i]);
;   }
;   return A;
; }
;
; void dsincos(double *__restrict x, double *__restrict xp, size_t n) {
;     __builtin_autodiff(iterA, x, xp, n);
; }

; Function Attrs: nounwind uwtable
define dso_local void @dsincos(double* noalias %x, double* noalias %xp, i64 %n) local_unnamed_addr #0 {
entry:
  %0 = tail call double (double (double*, i64)*, ...) @__enzyme_autodiff(double (double*, i64)* nonnull @iterA, double* %x, double* %xp, i64 %n)
  ret void
}

; Function Attrs: noinline norecurse nounwind readonly uwtable
define internal double @iterA(double* noalias nocapture readonly %x, i64 %n) #1 {
entry:
  %0 = load double, double* %x, align 8, !tbaa !2
  %exitcond11 = icmp eq i64 %n, 0
  br i1 %exitcond11, label %for.cond.cleanup, label %for.body.for.body_crit_edge

for.cond.cleanup:                                 ; preds = %for.body.for.body_crit_edge, %entry
  %cond.i.lcssa = phi double [ %0, %entry ], [ %cond.i, %for.body.for.body_crit_edge ]
  ret double %cond.i.lcssa

for.body.for.body_crit_edge:                      ; preds = %entry, %for.body.for.body_crit_edge
  %indvars.iv.next13 = phi i64 [ %indvars.iv.next, %for.body.for.body_crit_edge ], [ 1, %entry ]
  %cond.i12 = phi double [ %cond.i, %for.body.for.body_crit_edge ], [ %0, %entry ]
  %arrayidx2.phi.trans.insert = getelementptr inbounds double, double* %x, i64 %indvars.iv.next13
  %.pre = load double, double* %arrayidx2.phi.trans.insert, align 8, !tbaa !2
  %cmp.i = fcmp fast ogt double %cond.i12, %.pre
  %cond.i = select i1 %cmp.i, double %cond.i12, double %.pre
  %indvars.iv.next = add nuw i64 %indvars.iv.next13, 1
  %exitcond = icmp eq i64 %indvars.iv.next13, %n
  br i1 %exitcond, label %for.cond.cleanup, label %for.body.for.body_crit_edge
}

; Function Attrs: nounwind
declare double @__enzyme_autodiff(double (double*, i64)*, ...) #2

attributes #0 = { nounwind uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-jump-tables"="false" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #1 = { noinline norecurse nounwind readonly uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="true" "no-jump-tables"="false" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="true" "use-soft-float"="false" }
attributes #2 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang version 7.1.0 "}
!2 = !{!3, !3, i64 0}
!3 = !{!"double", !4, i64 0}
!4 = !{!"omnipotent char", !5, i64 0}
!5 = !{!"Simple C/C++ TBAA"}


; CHECK: define internal {{(dso_local )?}}void @diffeiterA(double* noalias nocapture readonly %x, double* nocapture %"x'", i64 %n, double %differeturn)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %exitcond11 = icmp eq i64 %n, 0
; CHECK-NEXT:   br i1 %exitcond11, label %invertentry, label %for.body.for.body_crit_edge.preheader

; CHECK: for.body.for.body_crit_edge.preheader:            ; preds = %entry
; CHECK-NEXT:   %0 = load double, double* %x, align 8, !tbaa !2
; CHECK-NEXT:   %malloccall = tail call noalias nonnull i8* @malloc(i64 %n)
; CHECK-NEXT:   %cmp.i_malloccache = bitcast i8* %malloccall to i1*
; CHECK-NEXT:   br label %for.body.for.body_crit_edge

; CHECK: for.body.for.body_crit_edge:                      ; preds = %for.body.for.body_crit_edge, %for.body.for.body_crit_edge.preheader
; CHECK-NEXT:   %[[indvar:.+]] = phi i64 [ %[[added:.+]], %for.body.for.body_crit_edge ], [ 0, %for.body.for.body_crit_edge.preheader ]
; CHECK-NEXT:   %cond.i12 = phi double [ %cond.i, %for.body.for.body_crit_edge ], [ %0, %for.body.for.body_crit_edge.preheader ]
; CHECK-NEXT:   %[[added]] = add nuw nsw i64 %[[indvar]], 1
; CHECK-NEXT:   %arrayidx2.phi.trans.insert = getelementptr inbounds double, double* %x, i64 %[[added]]
; CHECK-NEXT:   %.pre = load double, double* %arrayidx2.phi.trans.insert, align 8, !tbaa !2
; CHECK-NEXT:   %cmp.i = fcmp fast ogt double %cond.i12, %.pre
; CHECK-NEXT:   %[[ptrstore:.+]] = getelementptr inbounds i8, i8* %malloccall, i64 %[[indvar]]
; CHECK-NEXT:   %[[storeloc:.+]] = bitcast i8* %[[ptrstore]] to i1*
; CHECK-NEXT:   store i1 %cmp.i, i1* %[[storeloc]]
; CHECK-NEXT:   %cond.i = select i1 %cmp.i, double %cond.i12, double %.pre
; CHECK-NEXT:   %[[exitcond:.+]] = icmp eq i64 %[[added]], %n
; CHECK-NEXT:   br i1 %[[exitcond]], label %[[thelabel:.+]], label %for.body.for.body_crit_edge

; CHECK: invertentry:
; CHECK-NEXT:   %[[ientryde:.+]] = phi double [ %[[diffecond:.+]], %[[thelabel2:.+]] ], [ %differeturn, %entry ]
; CHECK-NEXT:   %[[xppre:.+]] = load double, double* %"x'"
; CHECK-NEXT:   %[[xpstore:.+]] = fadd fast double %[[xppre]], %[[ientryde]]
; CHECK-NEXT:   store double %[[xpstore]], double* %"x'"
; CHECK-NEXT:   ret

; CHECK: [[thelabel2]]:
; CHECK-NEXT:   tail call void @free(i8* nonnull %malloccall)
; CHECK-NEXT:   br label %invertentry

; CHECK: [[thelabel]]:
; CHECK-NEXT:   %[[iforde:.+]] = phi double [ %[[diffecond]], %[[thelabel]] ], [ %differeturn, %for.body.for.body_crit_edge ]
; CHECK-NEXT:   %[[iin:.+]] = phi i64 [ %[[isub:.+]], %[[thelabel]] ], [ %n, %for.body.for.body_crit_edge ]
; CHECK-NEXT:   %[[isub]] = add i64 %[[iin]], -1
; CHECK-NEXT:   %[[cmpcache:.+]] = getelementptr inbounds i1, i1* %cmp.i_malloccache, i64 %[[isub]]
; CHECK-NEXT:   %[[toselect:.+]] = load i1, i1* %[[cmpcache]]
; CHECK-NEXT:   %[[diffecond]] = select{{( fast)?}} i1 %[[toselect]], double %[[iforde]], double 0.000000e+00
; CHECK-NEXT:   %[[diffepre:.+]] = select{{( fast)?}} i1 %[[toselect]], double 0.000000e+00, double %[[iforde]]
; CHECK-NEXT:   %[[arrayidx2phitransinsertipg:.+]] = getelementptr inbounds double, double* %"x'", i64 %[[iin]]
; CHECK-NEXT:   %[[prear:.+]] = load double, double* %[[arrayidx2phitransinsertipg]]
; CHECK-NEXT:   %[[arradd:.+]] = fadd fast double %[[prear]], %[[diffepre]]
; CHECK-NEXT:   store double %[[arradd]], double* %[[arrayidx2phitransinsertipg]]
; CHECK-NEXT:   %[[lcmp:.+]] = icmp eq i64 %[[isub]], 0
; CHECK-NEXT:   br i1 %[[lcmp]], label %[[thelabel2]], label %[[thelabel]]
; CHECK-NEXT: }
