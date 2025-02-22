require import Int IntDiv Real Distr List.

from General require import ListExt Utils.
from Functionalities require import AProtocolFunctionality.
from SecretSharing require import ASecretSharingScheme SecretSharingSchemeSecurity.
from MPC require import AProtocol ProtocolPrivacy.
from Commitment require import ACommitmentScheme Binding Hiding.
from ZeroKnowledge require import AZKPProtocol Completeness Soundness ZeroKnowledge.

theory InTheHead.

  type witness_t.
  type instance_t.

  clone import SecretSharingScheme as SS with 
    type secret_t = witness_t.

  clone import Protocol as MPC with  
    op ProtocolFunctionality.n = SS.n,
    type ProtocolFunctionality.pid_t = SS.pid_t,
    op ProtocolFunctionality.pid_set = SS.pid_set,

    type ProtocolFunctionality.pinput_t = instance_t,
    type ProtocolFunctionality.sinput_t = share_t,

    (*op ProtocolFunctionality.valid_inputs (c : ProtocolFunctionality.circuit_t) (xs : inputs_t) = 
      unzip1 xs = pid_set /\
      exists r x, valid_rand r x /\ valid_secret x /\ share r x = map (fun pid => (pid, sinput pid xs)) pid_set,*)

    type ProtocolFunctionality.output_t = bool.
  import ProtocolFunctionality.

  axiom valid_inputs_implies_exists_rand c xs : 
    valid_inputs c xs =>  
      unzip1 xs = SS.pid_set /\
      exists r x, SS.valid_rand r x /\ valid_secret x /\ share r x = map (fun pid => (pid, sinput pid xs)) SS.pid_set.

  op relc : circuit_t.
  type statement_t = instance_t.
  axiom good_circuit (x : statement_t) w : 
    valid_circuit relc /\
    (forall ss ss', 
      reconstruct ss = w => reconstruct ss' = w =>
        let fss = f relc (mk_inputs x ss) in
        let fss' = f relc (mk_inputs x ss') in
        fss = fss' /\ unzip1 fss = SS.pid_set /\ (exists b, all (fun x => snd x = b) fss)).

  (*axiom valid_trace_protocol (c : circuit_t) (rs : rands_t) (xs : inputs_t) (pid : pid_t) : 
    pid \in SS.pid_set =>
    let (trs, ys) = protocol c rs xs in
    valid_circuit_trace c (trace pid trs).`2.*)

  clone import CommitmentScheme as CS with 
    type msg_t = input_t * rand_t * trace_t,
    op valid_rand r = true.

(*  clone import ZKFunctionality with
    type witness_t = witness_t,
    type statement_t = instance_t,
    op valid_inputs (x : (witness_t * statement_t) * statement_t) =
      let (x1,x2) = x in
      let (w,st1) = x1 in
      true,
    op relation (w : witness_t) (x : statement_t) =
      exists (ss : (pid_t * share_t) list),
        (w = reconstruct ss /\ 
          let xs = mk_inputs x ss (*map (fun pid => (pid, (x, oget (assoc ss pid)))) SS.pid_set*) in
          let outs = f relc xs in all (fun x => snd x) outs).
(*          forall x y, x \in unzip1 outs => y \in unzip1 outs => (oget (assoc outs x) = oget (assoc outs y) /\ oget (assoc outs x) /\ oget (assoc outs y))).*)*)

  type prover_input_t = witness_t * statement_t.
  type verifier_input_t = statement_t.
  type inputs_t = prover_input_t * verifier_input_t.

  op valid_inputs (x : inputs_t) : bool =
    let (xp,stv) = x in
    let (w,stp) = xp in 
    stp = stv /\ valid_secret w /\ 
    (forall rs, SS.valid_rand rs w => valid_inputs relc (mk_inputs stv (share rs w))).

  type prover_rand_t = SS.rand_t * MPC.rands_t * (pid_t * CS.rand_t) list.
  type verifier_rand_t = pid_t * pid_t.
  type rands_t = prover_rand_t * verifier_rand_t.

  type challenge_t = pid_t * pid_t.

  (* DISTR ATTEMPT *)
  op factorial : int -> int.
  axiom factorial0 : factorial 0 = 1.
  axiom factorialN x : 0 < x => factorial x = x * factorial (x-1).

  op pid_distr : pid_t distr.
  axiom pid_distr_ll : is_lossless pid_distr.
  axiom pid_distr_mem_pid_set x : x \in pid_distr => x \in SS.pid_set.
  axiom pid_distr1 x : x \in pid_distr => mu1 pid_distr x = 1%r / SS.n%r.

  op challenge_distr : challenge_t distr.
  axiom challenge_distr_ll : is_lossless challenge_distr.
  axiom challenge_mem_pid_set i j : (i,j) \in challenge_distr => 
                                    i \in SS.pid_set /\ j \in SS.pid_set.
  axiom challenge_distr_undup i j : i <> j => (i,j) \in challenge_distr => (j,i) \notin challenge_distr.
  axiom challenge_distr1 x : mu1 challenge_distr x = 1%r / (factorial SS.n %/ (2 * factorial (SS.n - 2)))%r.
  axiom challenge_distr_diff i j : (i,j) \in challenge_distr => i <> j.

  op valid_rand_verifier (r_v : verifier_rand_t) (x : statement_t) : bool =
    r_v \in challenge_distr.
  op valid_rand_prover (rp : prover_rand_t) (xp : prover_input_t) : bool =
    let (r_ss, r_mpc, r_cs) = rp in
    let (w,stp) = xp in
    SS.valid_rand r_ss w /\ 
    MPC.valid_rands relc r_mpc /\ unzip1 r_cs = SS.pid_set /\
    all (fun r_c => CS.valid_rand (snd r_c)) r_cs /\ size r_cs = SS.n /\ unzip1 r_cs = SS.pid_set.
  op valid_rands (r : rands_t) (x : inputs_t) : bool =
    let (xp,xv) = x in
    let (rp,rv) = r in
    valid_rand_verifier rv xv /\ valid_rand_prover rp xp.

  type prover_output_t = unit.
  type verifier_output_t = bool.
  type outputs_t = prover_output_t * verifier_output_t.

  type committed_view_t = MPC.view_t * CS.commit_info_t.
  type committed_views_t = (pid_t * committed_view_t) list. 

  op get_committed_view (pid : pid_t) (cvs : committed_views_t) : committed_view_t = oget (assoc cvs pid).

  type commitment_t = (pid_t * CS.commitment_t) list. 

  op get_party_commitment (pid : pid_t) (cv : commitment_t) : CS.commitment_t = oget (assoc cv pid).

  type response_t = (MPC.view_t * CS.opening_t) * 
                    (MPC.view_t * CS.opening_t).

  type prover_state_t = committed_views_t.
  type verifier_state_t = statement_t * commitment_t * challenge_t.

  op commit (rp : prover_rand_t) (xp : prover_input_t) : prover_state_t * commitment_t =
    let (w,x) = xp in
    let (r_ss, r_mpc, r_cs) = rp in

    let ws = SS.share r_ss w in

    let x_mpc = mk_inputs x ws in
    let (tr,y) = MPC.protocol relc r_mpc x_mpc in

    let vs = map (fun pid => (pid, (input pid x_mpc, rand pid r_mpc, trace pid tr))) SS.pid_set in
    let cvs = map (fun pid => 
                    let r_c = oget (assoc r_cs pid) in
                    let v = oget (assoc vs pid) in 
                    (pid, (v, commit r_c v))) SS.pid_set in
    let cs = map (fun pid => (pid, fst (snd (oget (assoc cvs pid))))) SS.pid_set in
    (cvs, cs).

  op challenge (rv : verifier_rand_t) (xv : verifier_input_t) (c : commitment_t) : verifier_state_t * challenge_t = ((xv,c,rv),rv).

  op get_party_committed_view (pid : pid_t) (cv : committed_views_t) : committed_view_t = oget (assoc cv pid).

  op response (stp : prover_state_t) (ch : challenge_t) : response_t = 
    let cvs = stp in
    let (i,j) = ch in

    let cvi = get_party_committed_view i cvs in
    let (vi, cii) = cvi in
    let cvj = get_party_committed_view j cvs in
    let (vj, cij) = cvj in

    ((vi, snd cii), (vj, snd cij)).

  op check (stv : verifier_state_t) (r : response_t) : bool = 
    let (xv, cs, rv) = stv in
    let (i,j) = rv in

    let (vosi, vosj) = r in
    let (vi, osi) = vosi in
    let (vj, osj) = vosj in

    let (xi,ri,tri) = vi in
    let (xj,rj,trj) = vj in

    let ci = get_party_commitment i cs in
    let cj = get_party_commitment j cs in

    CS.verify vi (ci,osi) /\ CS.verify vj (cj,osj) /\
    MPC.consistent_views_public relc xv vi vj i j /\
    MPC.local_output relc i vi /\ MPC.local_output relc j vj.

  op relation (w : witness_t) (x : statement_t) = 
    exists (ss : (pid_t * share_t) list), w = reconstruct ss /\ in_rng_share ss /\
      let outs = f relc (mk_inputs x ss) in all (fun x => snd x) outs.

  op language (x : statement_t) : bool =
    exists (w : witness_t), relation w x.

  type trace_t = commitment_t * challenge_t * response_t.

  clone import ZKPProtocol as InTheHead with
    type witness_t = witness_t,
    type statement_t = statement_t,
    op relation = relation,

    type prover_rand_t = prover_rand_t,
    type prover_state_t = prover_state_t,
    type commitment_t = commitment_t,
    type verifier_state_t = verifier_state_t,
    type verifier_rand_t = verifier_rand_t,
    type challenge_t = challenge_t,
    op chald = challenge_distr,
    type response_t = response_t,


    op valid_inputs = valid_inputs,
    op valid_rand_verifier = valid_rand_verifier,
    op valid_rand_prover = valid_rand_prover,

    op commit = commit,
    op challenge = challenge,
    op response = response,
    op check = check
  proof *.
  realize chald_ll by apply challenge_distr_ll.
  realize correct.
    move => r x />.
    elim x => xp xv.
    elim r => rp rv.
    rewrite /valid_inputs /valid_rands /valid_rand_prover /valid_rand_verifier => />.
    elim xp => wit stmt /=.
    elim rp => r_ss r_mpc r_cs /=.
    elim rv => i j /=.
    rewrite /valid_circuit /= !allP => />; progress.
    rewrite /protocol /f /relation /=.
    have H8 : (InTheHead.valid_inputs ((wit, xv), xv)).
      by rewrite /valid_inputs /=.

    rewrite /commit /= /challenge /= /response /=.

(*
(map (fun (pid : SS.pid_t) => (pid, (xv, oget (assoc (share r_ss wit) pid)))) SS.pid_set)
(map (fun (pid : SS.pid_t) => (pid, (xv, oget (assoc (share r_ss wit) pid)))) SS.pid_set)
*)

    have H9: exists tr y, (tr,y) = protocol relc r_mpc (mk_inputs xv (share r_ss wit)) by exists (protocol relc r_mpc (mk_inputs xv (share r_ss wit))).`1 (protocol relc r_mpc (mk_inputs xv (share r_ss wit))).`2 => /#.
    elim H9 => tr y H9; rewrite -H9 => /= *.
    rewrite /check => /> *.
     rewrite /get_party_committed_view /= !map_assoc //=; first 2 by smt(challenge_mem_pid_set). 
     rewrite /get_party_commitment /= !map_assoc //=; first 4 by smt(challenge_mem_pid_set).
     rewrite !map_assoc //=; first 2 by smt(challenge_mem_pid_set).
     rewrite !map_assoc //=; first 2 by smt(challenge_mem_pid_set).
     (*rewrite /input /= !map_assoc //=; first 2 by smt(challenge_mem_pid_set).*)
     have ->: verify (input i (mk_inputs xv (share r_ss wit)), rand i r_mpc, trace i tr)
   ((commit (oget (assoc r_cs i)) (input i (mk_inputs xv (share r_ss wit)), rand i r_mpc, trace i tr)).`1, (commit (oget (assoc r_cs i)) (input i (mk_inputs xv (share r_ss wit)), rand i r_mpc, trace i tr)).`2).
rewrite /mk_inputs /input !map_assoc; first by smt(challenge_mem_pid_set).
       move : (CS.correct (oget (assoc r_cs i)) ((((xv, oget (assoc (share r_ss wit) i)), rand i r_mpc, (trace i tr))))).
       have ->: valid_rand (oget (assoc r_cs i)).
by rewrite /valid_rand.
smt().

     simplify; have ->: verify (input j (mk_inputs xv (share r_ss wit)), rand j r_mpc, trace j tr)
   ((commit (oget (assoc r_cs j)) (input j (mk_inputs xv (share r_ss wit)), rand j r_mpc, trace j tr)).`1, (commit (oget (assoc r_cs j)) (input j (mk_inputs xv (share r_ss wit)), rand j r_mpc, trace j tr)).`2). 
rewrite /mk_inputs /input !map_assoc; first by smt(challenge_mem_pid_set).
       move : (CS.correct (oget (assoc r_cs j)) (((xv, oget (assoc (share r_ss wit) j)), rand j r_mpc, (trace j tr)))).
       have ->: valid_rand (oget (assoc r_cs j)).
by rewrite /valid_rand.
smt().

       simplify; progress.
       have ->: consistent_views_public relc xv (input i (mk_inputs xv (share r_ss wit)), rand i r_mpc, trace i tr) (input j (mk_inputs xv (share r_ss wit)), rand j r_mpc, trace j tr) i j.
rewrite /mk_inputs /= /input /= !map_assoc //=; first 2 by smt(challenge_mem_pid_set).
         rewrite /consistent_views /=.
         move : (messages_consistency relc i j (mk_inputs xv (share r_ss wit)) r_mpc).
         have ->: i \in ProtocolFunctionality.pid_set by smt(challenge_mem_pid_set).
         have ->: j \in ProtocolFunctionality.pid_set by smt(challenge_mem_pid_set).
         (*have ->: xv = stmt by (move : H H1; elim relc => topo gg; elim topo => np ns m q /= /#).*)
         rewrite -H9 /= /input /= !map_assoc //=; first 2 by smt(challenge_mem_pid_set).
        have ->: valid_rands relc r_mpc.
by rewrite /valid_rands H2 /=; progress; rewrite H3.
        have ->: valid_inputs relc (mk_inputs xv (share r_ss wit)).
          rewrite /valid_inputs /=.
          by move : (H0 r_ss); rewrite H1 /=; progress.

have ->: valid_circuit relc.
move : (good_circuit xv wit).
done.
done.

       move : (local_output_correct relc i (mk_inputs xv (share r_ss wit)) r_mpc).
       have ->: i \in ProtocolFunctionality.pid_set by smt(challenge_mem_pid_set).
         (*have ->: xv = stmt by (move : H H1; elim relc => topo gg; elim topo => np ns m q /= /#).*)

       rewrite -H9 /= /input /= !map_assoc //=; first 2 by smt(challenge_mem_pid_set).

       move : (local_output_correct relc j (mk_inputs xv (share r_ss wit)) r_mpc).
       have ->: j \in ProtocolFunctionality.pid_set by smt(challenge_mem_pid_set).
         (*have ->: xv = stmt by (move : H H1; elim relc => topo gg; elim topo => np ns m q /= /#).*)

       rewrite -H9 /= /input /= !map_assoc //=; first by smt(challenge_mem_pid_set).

       move : (MPC.correct relc r_mpc (mk_inputs xv (share r_ss wit))).
have ->: valid_inputs relc (mk_inputs xv (share r_ss wit)).
rewrite /valid_inputs /=.
move : (H0 r_ss).
by rewrite H1 /=.
simplify.

have ->: valid_rands relc r_mpc.
by rewrite /valid_rands H2 /=; progress.

have ->: valid_circuit relc.
move : (good_circuit xv wit).
done.

progress.


(*move : H8; rewrite /valid_inputs /=.
progress.
by move : (H3 r_ss); rewrite H1 /#.

have ->: valid_rands relc r_mpc.

by        rewrite /valid_rands //. 

       progress.
move : H H3 H15 H7 H8 H9 H10 H11 H12 H13; elim relc => topo gg.
elim topo => np ns m q /=.
progress.
move : H7.
rewrite /valid_rand /rand. 
progress.
rewrite H7.
by smt(challenge_mem_pid_set).
move : H H3 H15 H7 H8 H9 H10 H11 H12 H13; elim relc => topo gg.
elim topo => np ns m q /=.
progress.
move : H7.
rewrite /valid_rand /rand. 
progress.
rewrite H7.
by smt(challenge_mem_pid_set).
smt().
smt().

move : (valid_trace_protocol relc r_mpc (map
          (fun (pid : SS.pid_t) =>
             (pid, (stmt, oget (assoc (share r_ss wit) pid)))) SS.pid_set) i).
have ->: i \in SS.pid_set by
smt(challenge_mem_pid_set).
simplify.
rewrite -H15 /=.
move : (valid_trace_protocol relc r_mpc (map
          (fun (pid : SS.pid_t) =>
             (pid, (stmt, oget (assoc (share r_ss wit) pid)))) SS.pid_set) j).
have ->: j \in SS.pid_set by
smt(challenge_mem_pid_set).
simplify.
rewrite -H15 /=.

       move : (local_output_correct relc i (map (fun (pid : SS.pid_t) => (pid, (xv, oget (assoc (share r_ss wit) pid)))) SS.pid_set) r_mpc).
       have ->: i \in ProtocolFunctionality.pid_set by smt(challenge_mem_pid_set).
         have ->: xv = stmt by (move : H H1; elim relc => topo gg; elim topo => np ns m q /= /#).

       rewrite -H15 /= /input /= !map_assoc //=; first by  smt(challenge_mem_pid_set).

       move : (local_output_correct relc j (map (fun (pid : SS.pid_t) => (pid, (xv, oget (assoc (share r_ss wit) pid)))) SS.pid_set) r_mpc).
       have ->: j \in ProtocolFunctionality.pid_set by smt(challenge_mem_pid_set).
         have ->: xv = stmt by (move : H H1; elim relc => topo gg; elim topo => np ns m q /= /#).

       rewrite -H15 /= /input /= !map_assoc //=; first by  smt(challenge_mem_pid_set).

       move : (MPC.correct relc r_mpc (map (fun (pid : SS.pid_t) => (pid, (xv, oget (assoc (share r_ss wit) pid)))) SS.pid_set)).
have ->: valid_inputs relc
   (map
      (fun (pid : SS.pid_t) =>
         (pid, (xv, oget (assoc (share r_ss wit) pid)))) SS.pid_set).
move : H H3 H14 H15; rewrite /valid_inputs /=; elim relc => topo gg.
elim topo => np ns m q /=.
progress.
by move : (H3 r_ss); rewrite H1 /#.

have ->: valid_rands relc r_mpc.

by       rewrite /valid_rands //. *)

move : (good_circuit xv wit).


       progress.
(*move : H H3 H15 H7 H8 H9 H10 H11 H12 H13; elim relc => topo gg.
elim topo => np ns m q /=.
progress.*)
rewrite -H11 /=.
rewrite -H12 /=.
case (exists (ss : (ProtocolFunctionality.pid_t * share_t) list), wit = reconstruct ss /\ in_rng_share ss /\ all (fun (x : ProtocolFunctionality.pid_t * bool) => x.`2) (f relc (mk_inputs xv ss))); last first.
rewrite existsN; progress.
move : (H15 (share r_ss wit)).
have <-: wit = reconstruct (share r_ss wit).
smt(SS.correct).
simplify.
case (in_rng_share (share r_ss wit)); progress; last first.
move : H16; rewrite /in_rng_share.
rewrite existsN; progress.
move : (H16 r_ss).
rewrite existsN; progress.
move : (H17 wit).
by rewrite H H1 /=.

move : H17.
rewrite allP.
rewrite forallN.
progress.
have : ! ( !(x \in f relc (mk_inputs xv (share r_ss wit))) \/ x.`2).
smt().
progress.
have : (x \in
           f relc (mk_inputs xv (share r_ss wit))) by smt().
have : !x.`2 by smt().
progress.
move : (H14 (share r_ss wit) (share r_ss wit)).
have <-: wit = reconstruct (share r_ss wit).
smt(SS.correct).
simplify.
progress.
move : H22; rewrite allP.
progress.
have : b = false by smt(). 

have : (i, oget (assoc (f relc (mk_inputs xv (share r_ss wit))) i)) \in f relc (mk_inputs xv (share r_ss wit)).

rewrite assoc_get_mem.
rewrite H21.
by smt(challenge_mem_pid_set).
smt().

progress.

move : (H14 (share r_ss (reconstruct ss)) ss) => /=.
have ->: reconstruct (share r_ss (reconstruct ss)) = reconstruct ss by smt(SS.correct).
progress.
move : H16 H19; rewrite !allP.
progress.
have : (i, oget (assoc (f relc (mk_inputs xv (share r_ss (reconstruct ss)))) i)) \in f relc (mk_inputs xv (share r_ss (reconstruct ss))).
rewrite assoc_get_mem.
rewrite H17.
smt(challenge_mem_pid_set).
have : (j, oget (assoc (f relc (mk_inputs xv (share r_ss (reconstruct ss)))) j)) \in f relc (mk_inputs xv (share r_ss (reconstruct ss))).
rewrite assoc_get_mem.
rewrite H17.
smt(challenge_mem_pid_set).
progress.
have ->: y = (protocol relc r_mpc (mk_inputs xv (share r_ss (reconstruct ss)))).`2 by smt().
rewrite H10 /=.
rewrite /output /=.
rewrite H17 /=.
smt().
qed.

  clone import Completeness with theory ZKPProtocol <- InTheHead.

  section Completeness.
    import Completeness.

    declare module R : Rand_t.
    axiom r_gen_ll : islossless R.gen.

    lemma completeness &m w_ x_ : relation w_ x_ => Pr[Completeness(R).main(w_,x_) @ &m : res] = 1%r.
    proof.
      move => H; byphoare (_ : w_ = w /\ x = x_ ==> res) => //.
      proc.
      seq 1 : #pre => //.
        by call r_gen_ll.
        by wp; skip; progress; move : (correct (r_p{hr}, r_v{hr}) ((w{hr}, x{hr}), x{hr})) => /#.
        by hoare; call (_ : true).
      qed.

  end section Completeness.

  clone import Binding with theory CommitmentScheme <- CS, type aux_t = statement_t.
  clone import Soundness with theory ZKPProtocol <- InTheHead.

  section Soundness.

    module type MProverLow_t = {
      proc gen_commitment(x : statement_t) : (SS.pid_t * (input_t * MPC.rand_t * MPC.trace_t)) list * (SS.pid_t * CS.rand_t) list
    }.
    op mgen_response : committed_views_t -> statement_t -> InTheHead.commitment_t -> InTheHead.challenge_t -> InTheHead.response_t.

    module MProver (MPL : MProverLow_t) = {
      var cvs : committed_views_t
      var c : commitment_t

      proc commitment(x : statement_t) : commitment_t = {
        var vs, crs, cs;

        (vs,crs) <@ MPL.gen_commitment(x);
        cvs <- map (fun pid => 
                    let r_c = oget (assoc crs pid) in
                    let ysv = oget (assoc vs pid) in 
                    (pid, (ysv, commit r_c ysv))) SS.pid_set;
        cs <- map (fun pid => (pid, fst (snd (oget (assoc cvs pid))))) SS.pid_set;
        c <- cs;
        cvs <- map (fun pid => (pid, ((oget (assoc vs pid)), commit (oget (assoc crs pid)) (oget (assoc vs pid))))) SS.pid_set;

        return cs;
      }

      proc response(x : statement_t, ch : challenge_t) : response_t = {
        var resp;
        resp <- mgen_response cvs x c ch;
        return resp;
      }
    }.

    module Game1(RV : RandV_t, MP : MProverLow_t) = {
      var bad : bool

      proc main(x : statement_t) : bool = {
        var r_v, b, c, ch, resp, acceptance, vs,crs,stv;
        var i, j, vosi, vosj, vi, osi, vi', ci, cvs, osi';

        r_v <@ RV.gen();
        bad <- false;
        (vs,crs) <@ MP.gen_commitment(x);
        cvs <- map (fun pid => 
                    let r_c = oget (assoc crs pid) in
                    let v = oget (assoc vs pid) in 
                    (pid, (v, commit r_c v))) SS.pid_set;
        c <- map (fun pid => (pid, fst (snd (oget (assoc cvs pid))))) SS.pid_set;

        if (valid_rand_verifier r_v x) {

          (stv,ch) <- challenge r_v x c;
          (i,j) <- ch;

          resp <- mgen_response cvs x c ch;

          (vosi, vosj) <- resp;
          (vi, osi) <- vosi;

          vi' <- fst (get_committed_view i cvs);
          osi' <- snd (snd (get_committed_view i cvs));

          ci <- get_party_commitment i c;

          bad <- (vi <> vi' /\ verify vi (ci,osi));
          if (!bad) {
            acceptance <- !language x /\ check stv resp;
            b <- (acceptance);
          } else { b <- false; } 
        } else { b <- false; }

        return b;
      }
    }.

    module Game2(RV : RandV_t, MP : MProverLow_t) = {
      var bad, bad' : bool

      proc main(x : statement_t) : bool = {
        var r_v, b, c, ch, resp, acceptance, vs, crs, stv;
        var i, j, vosi, vosj, vi, osi, vi', ci, cvs, vj, osj, vj', cj, osi', osj';

        r_v <@ RV.gen();
        bad <- false;
        bad' <- false;
        (vs,crs) <@ MP.gen_commitment(x);
        cvs <- map (fun pid => 
                    let r_c = oget (assoc crs pid) in
                    let v = oget (assoc vs pid) in 
                    (pid, (v, commit r_c v))) SS.pid_set;
        c <- map (fun pid => (pid, fst (snd (oget (assoc cvs pid))))) SS.pid_set;

        if (valid_rand_verifier r_v x) {

          (stv,ch) <- challenge r_v x c;
          (i,j) <- ch;

          resp <- mgen_response cvs x c ch;

          (vosi, vosj) <- resp;
          (vi, osi) <- vosi;
          (vj, osj) <- vosj;

          vi' <- fst (get_committed_view i cvs);
          osi' <- snd (snd (get_committed_view i cvs));
          vj' <- fst (get_committed_view j cvs);
          osj' <- snd (snd (get_committed_view j cvs));

          ci <- get_party_commitment i c;
          cj <- get_party_commitment j c;

          bad <- vi <> vi' /\ verify vi (ci,osi);
          bad' <- vj <> vj' /\ verify vj (cj,osj);
          if (!bad /\ !bad') {
            acceptance <- !language x /\ check stv resp;
            b <- (acceptance);
          } else { b <- false; }
        } else { b <- false; }

        return b;
      }
    }.

    module B (RV : RandV_t, MP : MProverLow_t) = {
      proc choose(x : statement_t) : CS.commitment_t * msg_t * opening_t * msg_t * opening_t = {
        var r_v, c, ch, resp, cvs, vs, crs, stv;
        var i, j, vosi, vosj, vi, osi, vi', ci, osi', ret;

        r_v <@ RV.gen();
        (vs,crs) <@ MP.gen_commitment(x);
        cvs <- map (fun pid => 
                    let r_c = oget (assoc crs pid) in
                    let v = oget (assoc vs pid) in 
                    (pid, (v, commit r_c v))) SS.pid_set;
        c <- map (fun pid => (pid, fst (snd (oget (assoc cvs pid))))) SS.pid_set;
        ret <- (witness,witness,witness,witness,witness);
        if (valid_rand_verifier r_v x) {

          (stv,ch) <- challenge r_v x c;
          (i,j) <- ch;

          resp <- mgen_response cvs x c ch;

          (vosi, vosj) <- resp;
          (vi, osi) <- vosi;

          vi' <- fst (get_committed_view i cvs);
          osi' <- snd (snd (get_committed_view i cvs));
          ci <- get_party_commitment i c;

          ret <- (ci, vi, osi, vi', osi');
        }

        return ret;
      }
    }.

    module C (RV : RandV_t, MP : MProverLow_t) = {
      proc choose(x : statement_t) : CS.commitment_t * msg_t * opening_t * msg_t * opening_t = {
        var r_v, c, ch, resp, cvs, vs, crs, stv;
        var i, j, vosi, vosj, vi, osi, vi', ci, osi', ret;

        r_v <@ RV.gen();
        (vs,crs) <@ MP.gen_commitment(x);
        cvs <- map (fun pid => 
                    let r_c = oget (assoc crs pid) in
                    let v = oget (assoc vs pid) in 
                    (pid, (v, commit r_c v))) SS.pid_set;
        c <- map (fun pid => (pid, fst (snd (oget (assoc cvs pid))))) SS.pid_set;

        ret <- (witness,witness,witness,witness,witness);
        if (valid_rand_verifier r_v x) {

          (stv,ch) <- challenge r_v x c;
          (i,j) <- ch;

          resp <- mgen_response cvs x c ch;

          (vosi, vosj) <- resp;
          (vi, osi) <- vosj;

          vi' <- fst (get_committed_view j cvs);
          osi' <- snd (snd (get_committed_view j cvs));
          ci <- get_party_commitment j c;

          ret <- (ci, vi, osi, vi', osi');
        }

        return ret;
      }
    }.

    module RV = {
      proc gen() : verifier_rand_t = {
        var rv;
        rv <$ challenge_distr;
        return rv;
      }
    }.

    declare module MPL : MProverLow_t{RV,MProver,Game1,Game2}.

    lemma game_game1_equiv : 
      equiv [ Soundness(RV,MProver(MPL)).main ~ Game1(RV,MPL).main :
        ={glob RV, glob MPL, x} ==> !Game1.bad{2} => ={res} ].
    proof.
      proc; inline*.
      sp; seq 1 1 : (#pre /\ = {rv} /\ rv{1} \in chald); first by inline*; auto.
      sp; seq 1 1 : (#pre /\ ={vs, crs}); first by call (_ : true).
      by wp; skip; progress => /#.
    qed. 

    lemma game_game1_pr &m x : 
      Pr [ Soundness(RV,MProver(MPL)).main(x) @ &m : res ] <=
      Pr [ Game1(RV,MPL).main(x) @ &m : res ] + 
      Pr [ Game1(RV,MPL).main(x) @ &m : Game1.bad ].
    proof. by byequiv game_game1_equiv => /#. qed.

    lemma bad1_pr &m inst :
      Pr [ Game1(RV,MPL).main(inst) @ &m : Game1.bad ] <= 
      Pr [ Binding.Game(B(RV,MPL)).main(inst) @ &m : res].
    proof.
      byequiv (_ : ={glob RV, glob MPL} /\ x{1} = aux{2} ==> Game1.bad{1} = res{2}) => //=.
      proc; inline*.
      sp; seq 1 1 : (#pre /\ ={rv}); first by rnd.
      sp; seq 1 1 : (#pre /\ ={vs,crs}); first by call (_ : true); skip.
      sp 2 3; if; last by wp.
        by smt().
     sp 9 0; if{1}; last first.
       wp; skip; progress. 
       move : H H0 H2 H3.
       rewrite /get_committed_view /get_party_commitment /gen_challenge /= => H.
       have ->: (map (fun (pid : SS.pid_t) => (pid, (oget (assoc (map (fun (pid0 : SS.pid_t) => (pid0, (oget (assoc vs{2} pid0), commit (oget (assoc crs{2} pid0)) (oget (assoc vs{2} pid0))))) SS.pid_set) pid)).`2.`1)) SS.pid_set) = (map (fun (pid : SS.pid_t) => (pid, ((assoc vs{2} pid), commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))).`2.`1)) SS.pid_set).
         by rewrite -eq_in_map; progress; rewrite map_assoc //=.
       pose cvs := (map (fun (pid : SS.pid_t) => (pid, (oget (assoc vs{2} pid), commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))))) SS.pid_set).
       pose c := (map (fun (pid : SS.pid_t) => (pid, (assoc vs{2} pid, commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))).`2.`1)) SS.pid_set).
       progress; rewrite H3 H2 /=.
       have ->: verify (mgen_response cvs aux{2} c rv{2}).`1.`1 (oget (assoc c rv{2}.`1), (mgen_response cvs aux{2} c rv{2}).`1.`2) by smt().
       have ->: verify (oget (assoc cvs rv{2}.`1)).`1 (oget (assoc c rv{2}.`1), (oget (assoc cvs rv{2}.`1)).`2.`2).
         move : (CS.correct (oget (assoc crs{2} rv{2}.`1)) (oget (assoc cvs rv{2}.`1)).`1). 
         rewrite /valid_rand /= /cvs !map_assoc //=; first 2 by smt.
         by smt().
       by smt().
     by wp; skip; progress => /#.
   qed.

   lemma game1_game2_equiv : 
     equiv [ Game1(RV,MPL).main ~ Game2(RV,MPL).main :
       ={x, glob RV, glob MPL} ==> !Game2.bad'{2} => ={res} ].
   proof.
     proc; inline*.
     sp; seq 1 1 : (#pre /\ = {rv} /\ rv{1} \in challenge_distr); first by inline*; auto.
     sp ;seq 1 1 : (#pre /\ ={vs, crs}); first by call (_ : true).
     wp; skip; progress.
     move : H1 H2 H3 H4 H5.
     rewrite /gen_challenge /get_committed_view /get_party_commitment /= !map_assoc //=; first 4 by smt.
     have ->: (map (fun (pid : SS.pid_t) => (pid, (oget (assoc (map (fun (pid0 : SS.pid_t) => (pid0, (oget (assoc vs{2} pid0), commit (oget (assoc crs{2} pid0)) (oget (assoc vs{2} pid0))))) SS.pid_set) pid)).`2.`1)) SS.pid_set) = (map (fun (pid : SS.pid_t) => (pid, ((assoc vs{2} pid), commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))).`2.`1)) SS.pid_set).
       by rewrite -eq_in_map; progress; rewrite map_assoc //=.
     pose cvs := (map (fun (pid : SS.pid_t) => (pid, (oget (assoc vs{2} pid), commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))))) SS.pid_set).
     pose c := (map (fun (pid : SS.pid_t) => (pid, (assoc vs{2} pid, commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))).`2.`1)) SS.pid_set).
     by smt().
     by smt().
    qed.

    lemma game1_game2_pr &m x : 
      Pr [ Game1(RV,MPL).main(x) @ &m : res ] <=
      Pr [ Game2(RV,MPL).main(x) @ &m : res ] + 
      Pr [ Game2(RV,MPL).main(x) @ &m : Game2.bad' ].
    proof. by byequiv game1_game2_equiv => /#. qed.

    lemma bad2_pr &m inst :
      Pr [ Game2(RV,MPL).main(inst) @ &m : Game2.bad' ] <= 
      Pr [ Binding.Game(C(RV,MPL)).main(inst) @ &m : res].
    proof.
      byequiv (_ : ={glob RV, glob MPL} /\ x{1} = aux{2} ==> Game2.bad'{1} = res{2}) => //=.
      proc; inline*.
      sp; seq 1 1 : (#pre /\ ={rv}); first by rnd.
      sp; seq 1 1 : (#pre /\ ={vs,crs}); first by call (_ : true); skip.
      sp 2 3; if; last by wp.
        by smt().
       sp 14 0; case (Game2.bad'{1}).
         rcondf{1} 1; first by progress; wp; skip; progress => /#.
         wp; skip; progress.
         move : H H0 H2 H3.
         rewrite /get_committed_view /get_party_commitment /gen_challenge /= => H.
         have ->: (map (fun (pid : SS.pid_t) => (pid, (oget (assoc (map (fun (pid0 : SS.pid_t) => (pid0, (oget (assoc vs{2} pid0), commit (oget (assoc crs{2} pid0)) (oget (assoc vs{2} pid0))))) SS.pid_set) pid)).`2.`1)) SS.pid_set) = (map (fun (pid : SS.pid_t) => (pid, ((assoc vs{2} pid), commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))).`2.`1)) SS.pid_set).
           by rewrite -eq_in_map; progress; rewrite map_assoc //=.
         pose cvs := (map (fun (pid : SS.pid_t) => (pid, (oget (assoc vs{2} pid), commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))))) SS.pid_set).
         pose c := (map (fun (pid : SS.pid_t) => (pid, (assoc vs{2} pid, commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))).`2.`1)) SS.pid_set).
         progress. 
         have ->: verify (mgen_response cvs aux{2} c rv{2}).`2.`1 (oget (assoc c rv{2}.`2), (mgen_response cvs aux{2} c rv{2}).`2.`2) by smt().
         have ->: verify (oget (assoc cvs rv{2}.`2)).`1 (oget (assoc c rv{2}.`2), (oget (assoc cvs rv{2}.`2)).`2.`2).
           move : (CS.correct (oget (assoc crs{2} rv{2}.`2)) (oget (assoc cvs rv{2}.`2)).`1). 
           rewrite /valid_rand /= /cvs !map_assoc //=; first 2 by smt.
           by smt().
         by smt().
       case (Game2.bad{1}).
         rcondf{1} 1; first by progress; wp; skip; progress => /#.
         wp; skip; progress.
         move : H H0 H2 H3 H4.
         rewrite /get_committed_view /get_party_commitment /gen_challenge /= => H.
         have ->: (map (fun (pid : SS.pid_t) => (pid, (oget (assoc (map (fun (pid0 : SS.pid_t) => (pid0, (oget (assoc vs{2} pid0), commit (oget (assoc crs{2} pid0)) (oget (assoc vs{2} pid0))))) SS.pid_set) pid)).`2.`1)) SS.pid_set) = (map (fun (pid : SS.pid_t) => (pid, ((assoc vs{2} pid), commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))).`2.`1)) SS.pid_set).
           by rewrite -eq_in_map; progress; rewrite map_assoc //=.
         pose cvs := (map (fun (pid : SS.pid_t) => (pid, (oget (assoc vs{2} pid), commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))))) SS.pid_set).
         pose c := (map (fun (pid : SS.pid_t) => (pid, (assoc vs{2} pid, commit (oget (assoc crs{2} pid)) (oget (assoc vs{2} pid))).`2.`1)) SS.pid_set).
         by smt(). 
       by wp; skip; progress => /#.
    qed.

   lemma game2_pr &m x_ : 
     Pr[Game2(RV, MPL).main(x_) @ &m : res] <= 1%r - (1%r / (factorial SS.n %/ (2 * factorial (SS.n - 2)))%r).
   proof.
     byphoare => //.
     proc; inline*.
      case (language x).
        hoare; first by smt(@Real).
        by wp; call (_ : true); wp; rnd; wp; skip => /#.
swap 5 -4; sp.
     seq 1 : (!language x) (1%r) (1%r - (1%r / (factorial SS.n %/ (2 * factorial (SS.n - 2)))%r)) _ 0%r => //; last first.
       by hoare; first by wp; rnd; wp; skip => /#.
     wp; rnd ;wp; skip; progress.
     rewrite /gen_challenge /=.
     pose cvs := (map (fun (pid : SS.pid_t) => (pid, (oget (assoc vs{hr} pid), commit (oget (assoc crs{hr} pid)) (oget (assoc vs{hr} pid))))) SS.pid_set).
     pose c := (map (fun (pid : SS.pid_t) => (pid, (oget (assoc cvs pid)).`2.`1)) SS.pid_set).
     move : H; progress.
     rewrite /get_committed_view /get_party_commitment /=.
     case (exists rs sx, 
             unzip1 sx = SS.pid_set /\
             let xs = map (fun pid => (pid, (x{hr}, oget (assoc sx pid)))) SS.pid_set in 
             valid_rands relc rs /\ valid_inputs relc xs /\
             let (tr,y) = protocol relc rs xs in
             (forall pid, pid \in SS.pid_set => (oget (assoc cvs pid)).`1 = 
               (((input pid xs, rand pid rs, (trace pid tr)))))); progress.
       move : H H1 H2; pose st := (x{hr}); progress.
       have : exists tr y, (tr,y) = protocol relc rs (mk_inputs st sx) by
         exists (protocol relc rs (mk_inputs st sx)).`1;
         exists (protocol relc rs (mk_inputs st sx)).`2 => /#.
       progress.
       move : H3; rewrite -H4 /input /=; progress.
       have : forall pid, pid \in SS.pid_set => (oget (assoc cvs pid)).`1 = ((((st, oget (assoc sx pid)), rand pid rs, (trace pid tr)))).
         by progress; move : (H3 pid); rewrite H5 !map_assoc //=.
       progress.
       rewrite mu0_false; progress.
         rewrite /valid_rand_verifier /= H6 /= /check.
         move : H6; elim x0 => i j.
         progress.
         have : exists (vosi, vosj), (vosi, vosj) = mgen_response cvs st c (i, j) by
           exists (mgen_response cvs st c (i, j)).`1 (mgen_response cvs st c (i, j)).`2 => /#.
         progress; rewrite -H7 /=.
         move : H7.
         elim vosi0 => vi osi.
         elim vosj0 => vj osj.
         elim vi => xi ri tri /=.
         elim vj => xj rj trj /=.
         progress.
         case (! (((xi, ri, tri)) <> (oget (assoc cvs i)).`1 /\ verify ((xi, ri, tri)) (oget (assoc c i), osi))); last by smt().
         progress.
         case (! (((xj, rj, trj)) <> (oget (assoc cvs j)).`1 /\ verify ((xj, rj, trj)) (oget (assoc c j), osj))); last by smt().
         progress.
         case (verify ((xi, ri, tri)) (get_party_commitment i c, osi)); last by smt().
         progress; case (verify ((xj, rj, trj)) (get_party_commitment j c, osj)); last by smt().
         progress.
         have : ((xi, ri, tri)) = (oget (assoc cvs i)).`1 by smt().
         have : ((xj, rj, trj)) = (oget (assoc cvs j)).`1 by smt().
         progress.
         move : (MPC.correct relc rs (mk_inputs st sx)).
         have ->: valid_circuit relc.
move : (good_circuit st (reconstruct sx)).
done.
         rewrite H1 H2 /=; progress.
         move : (MPC.local_output_correct relc i (mk_inputs st sx) rs).
         have ->: i \in ProtocolFunctionality.pid_set by smt(challenge_mem_pid_set).
         rewrite -H4 /= /input /= map_assoc //=; first by smt(challenge_mem_pid_set).
         rewrite /challenge /=; progress. 
         move : (MPC.local_output_correct relc j (mk_inputs st sx) rs).
         have ->: j \in ProtocolFunctionality.pid_set by smt(challenge_mem_pid_set).
         rewrite -H4 /= /input /= map_assoc //=; first by smt(challenge_mem_pid_set).
         rewrite /challenge /=; progress. 

have ->: xi = (st, oget (assoc sx i)) by smt(challenge_mem_pid_set).
have ->: ri = (rand i rs) by smt(challenge_mem_pid_set).
have ->: (tri) = trace i tr by smt(challenge_mem_pid_set).

have ->: xj = (st, oget (assoc sx j)) by smt(challenge_mem_pid_set).
have ->: rj = (rand j rs) by smt(challenge_mem_pid_set).
have ->: (trj) = trace j tr by smt(challenge_mem_pid_set).

          rewrite -H15 -H16.
         have ->: y = (protocol relc rs (mk_inputs st sx)).`2 by smt().

have : output i (protocol relc rs (mk_inputs st sx)).`2 = output i (f relc (mk_inputs st sx)).
move : (good_circuit st (reconstruct (map (fun (pid : SS.pid_t) => (pid, (oget (assoc sx pid)))) SS.pid_set))).
progress.
move : (H18 (map (fun (pid : SS.pid_t) => (pid, oget (assoc sx pid))) SS.pid_set) ((map (fun (pid : SS.pid_t) => (pid, oget (assoc sx pid))) SS.pid_set))).
simplify.
progress.
move : H20; rewrite allP; progress.
have : (i, oget (assoc (f relc (mk_inputs st sx)) i)) \in f relc (mk_inputs st (map (fun (pid : SS.pid_t) => (pid, oget (assoc sx pid))) SS.pid_set)).
(*         (map
            (fun (pid : SS.pid_t) =>
               (pid, (st, oget (assoc (map (fun (pid0 : SS.pid_t) => (pid0, oget (assoc sx pid0))) SS.pid_set) pid))))
            SS.pid_set).*)
have ->: (mk_inputs st (map (fun (pid : SS.pid_t) => (pid, oget (assoc sx pid))) SS.pid_set)) = (mk_inputs st sx). (*(map (fun (pid : SS.pid_t) => (pid, (st, oget (assoc sx pid)))) SS.pid_set).*)
rewrite -eq_in_map => pid; progress.
by rewrite !map_assoc //=.
rewrite assoc_get_mem.
smt.

have : (j, oget (assoc (f relc (mk_inputs st sx)) j)) \in f relc (mk_inputs st (map (fun (pid : SS.pid_t) => (pid, oget (assoc sx pid))) SS.pid_set)).
(*         (map
            (fun (pid : SS.pid_t) =>
               (pid, (st, oget (assoc (map (fun (pid0 : SS.pid_t) => (pid0, oget (assoc sx pid0))) SS.pid_set) pid))))
            SS.pid_set).*)
have ->: (mk_inputs st (map (fun (pid : SS.pid_t) => (pid, oget (assoc sx pid))) SS.pid_set)) = (mk_inputs st sx). (*(map (fun (pid : SS.pid_t) => (pid, (st, oget (assoc sx pid)))) SS.pid_set).*)
rewrite -eq_in_map => pid; progress.
by rewrite !map_assoc //=.
rewrite assoc_get_mem.
smt.

progress.
move : (H20 (j, oget (assoc (f relc (mk_inputs st sx)) j))).
rewrite H21.
move : (H20 (i, oget (assoc (f relc (mk_inputs st sx)) i))).
rewrite H22.
rewrite /output /#.

progress.
rewrite H17.
         move : H; rewrite /language /=; progress; rewrite H /=.
         have : forall w, !relation w st by smt().
         rewrite /relation /=; progress; move : (H18 (reconstruct sx)); progress.
         have : forall (ss : (ProtocolFunctionality.pid_t * share_t) list), !(reconstruct sx = reconstruct ss /\ in_rng_share ss /\
          all (fun (x : ProtocolFunctionality.pid_t * bool) => x.`2)
            (f relc (mk_inputs st ss))) by rewrite -existsN. 
progress.
move : (H20 sx) => /=.
have ->: in_rng_share sx.
rewrite /in_rng_share.

have : unzip1 (map (fun (pid : SS.pid_t) => (pid, (st, oget (assoc sx pid))))
         SS.pid_set) = SS.pid_set /\
      exists r x, SS.valid_rand r x /\ valid_secret x /\ share r x = map (fun pid => (pid, sinput pid (map (fun (pid : SS.pid_t) => (pid, (st, oget (assoc sx pid))))
         SS.pid_set))) SS.pid_set.
rewrite (valid_inputs_implies_exists_rand relc
      (map (fun (pid : SS.pid_t) => (pid, (st, oget (assoc sx pid))))
         SS.pid_set)).
done.

rewrite -map_comp /(\o) map_id //=.
progress.
move : H23; rewrite /sinput /input /=.
have ->: map
  (fun (pid : pid_t) =>
     (pid,
      (oget
         (assoc
            (map
               (fun (pid0 : SS.pid_t) => (pid0, (st, oget (assoc sx pid0))))
               SS.pid_set) pid)).`2)) ProtocolFunctionality.pid_set = 
map
  (fun (pid : pid_t) =>
     (pid, oget (assoc sx pid))) ProtocolFunctionality.pid_set.
rewrite -eq_in_map; progress.
by rewrite map_assoc //=.
have ->: ProtocolFunctionality.pid_set = unzip1 sx by smt().
rewrite -eq_assoc_map.
by rewrite H0 pid_set_uniq.
progress.
by exists r x0.


rewrite allP; progress.

(************)
have : exists (x : ProtocolFunctionality.pid_t * bool),
          !(x \in f relc (mk_inputs st sx) =>
          x.`2) by smt().
progress.
have : x0 \in f relc (mk_inputs st sx).
smt().
have : !x0.`2.
smt().
move : (good_circuit st (reconstruct sx)).
progress.
move : (H24 sx sx).
simplify.
progress.
move : H28; rewrite allP; progress.
move : (H28 (i,output i (f relc (mk_inputs st sx)))).
have ->: (i, output i (f relc (mk_inputs st sx))) \in
 f relc (mk_inputs st sx).
rewrite /output /= assoc_get_mem.
smt.
smt().

       by smt(@Real).
     progress.
     have H1 : forall pid, pid \in SS.pid_set => (oget (assoc cvs pid)).`1 = oget (assoc (map (fun (pid0 : SS.pid_t) => (pid0, (oget (assoc cvs pid0)).`1)) SS.pid_set) pid).
progress; rewrite /cvs !map_assoc //=.
by rewrite !map_assoc //=.
     have : !(forall (i j : SS.pid_t), i \in SS.pid_set => j \in SS.pid_set => consistent_views_public relc x{hr} ((oget (assoc cvs i)).`1) ((oget (assoc cvs j)).`1) i j).
     move : (global_consistency relc x{hr} (map (fun pid => (pid, (oget (assoc cvs pid)).`1)) SS.pid_set)); progress.
       have : !exists (rs : MPC.rands_t) (sx : (ProtocolFunctionality.pid_t * sinput_t) list), unzip1 sx = SS.pid_set /\ valid_rands relc rs /\ valid_inputs relc (mk_inputs x{hr} sx) /\ let (tr, _) = protocol relc rs (mk_inputs x{hr} sx) in (forall (pid : ProtocolFunctionality.pid_t), pid \in ProtocolFunctionality.pid_set => (oget (assoc cvs pid)).`1 = ((((input pid (mk_inputs x{hr} sx), rand pid rs, (trace pid tr)))))).
         rewrite existsN; move : H0; rewrite existsN; progress.
         rewrite existsN; progress; move : (H0 x0); rewrite !existsN; progress.
         move : (H3 x1); progress => /#.

have : (exists (rs : MPC.rands_t) (sx : (SS.pid_t * sinput_t) list),
        unzip1 sx = SS.pid_set /\
         valid_rands relc rs /\
         valid_inputs relc (mk_inputs x{hr} sx) /\
         let (tr, _) = protocol relc rs (mk_inputs x{hr} sx)
         in
         (forall (pid : SS.pid_t),
            pid \in SS.pid_set =>
            (oget (assoc cvs pid)).`1 =
            (
             (input pid (mk_inputs x{hr} sx), 
              rand pid rs, (trace pid tr))))) <=> 
(exists (rs : MPC.rands_t) (sx : (ProtocolFunctionality.pid_t * sinput_t) list),
        unzip1 sx = SS.pid_set /\
     valid_rands relc rs /\
     valid_inputs relc
       (mk_inputs x{hr} sx) /\
     let (tr, _) =
       protocol relc rs
         (mk_inputs x{hr} sx) in
     (forall (pid : ProtocolFunctionality.pid_t),
        pid \in ProtocolFunctionality.pid_set =>
        oget (assoc (map (fun (pid0 : SS.pid_t) => (pid0, (oget (assoc cvs pid0)).`1)) SS.pid_set) pid) =
        (
         (input pid
            (mk_inputs x{hr} sx), rand pid rs, (trace pid tr))))).
progress.
exists rs sx.
rewrite H4 H5 /=.
progress.
rewrite /input !map_assoc //=.
rewrite /cvs !map_assoc //=.
move : H6; rewrite H7 /=.
progress.
move : (H6 pid) => //=. 
by rewrite H8 /cvs /input !map_assoc //=.
progress.
exists rs sx.
rewrite H4 H5 /=.
progress.
move : H6; rewrite H7 /=.
progress.
rewrite /cvs !map_assoc //=.
rewrite -H6 //=.
rewrite !map_assoc //=.
by rewrite /cvs !map_assoc //=.
progress.

progress.
have ->: (forall (i j : SS.pid_t),
     i \in SS.pid_set =>
     j \in SS.pid_set => consistent_views_public relc x{hr} (oget (assoc cvs i)).`1 (oget (assoc cvs j)).`1 i j) <=> 
(forall (i j : SS.pid_t),
     i \in SS.pid_set =>
     j \in SS.pid_set => consistent_views_public relc x{hr} (oget (assoc (map (fun (pid : SS.pid_t) => (pid, (oget (assoc cvs pid)).`1)) SS.pid_set) i)) (oget (assoc (map (fun (pid : SS.pid_t) => (pid, (oget (assoc cvs pid)).`1)) SS.pid_set) j)) i j).
split.
move => H5 i j hi hj.
rewrite map_assoc //=.
have ->: (oget (assoc (map (fun (pid : SS.pid_t) => (pid, (oget (assoc cvs pid)).`1)) SS.pid_set) j)) = (oget (assoc cvs j)).`1.
by rewrite map_assoc //=.
rewrite H5 //=.
move => H5 i j hi hj.
have ->: (oget (assoc cvs i)).`1 = (oget (assoc (map (fun (pid : SS.pid_t) => (pid, (oget (assoc cvs pid)).`1)) SS.pid_set) i)).
have ->: (oget (assoc (map (fun (pid : SS.pid_t) => (pid, (oget (assoc cvs pid)).`1)) SS.pid_set) i)) = (oget (assoc cvs i)).`1.
by rewrite map_assoc //=.
done.
have ->: (oget (assoc cvs j)).`1 = (oget (assoc (map (fun (pid : SS.pid_t) => (pid, (oget (assoc cvs pid)).`1)) SS.pid_set) j)).
have ->: (oget (assoc (map (fun (pid : SS.pid_t) => (pid, (oget (assoc cvs pid)).`1)) SS.pid_set) j)) = (oget (assoc cvs j)).`1.
by rewrite map_assoc //=.
done.
by rewrite H5 //=.

(*move : (H2 i0 j0); rewrite H6 H7 /=.
by rewrite !map_assoc //= /cvs !map_assoc //=. 
rewrite H2.
rewrite -H3.
rewrite H4.
done.*)
move : H2.
have ->: valid_circuit relc.
move : (good_circuit x{hr} witness).
done.
simplify.
rewrite /consistent_trace_public.
move => H2.
rewrite H2.
rewrite -H3.
rewrite H4.
done.

     progress.
     have H3: exists (ch : challenge_t), !consistent_views_public relc x{hr} (oget (assoc cvs ch.`1)).`1 (oget (assoc cvs ch.`2)).`1 ch.`1 ch.`2.
       have H4: exists i j, !consistent_views_public relc x{hr} (oget (assoc cvs i)).`1 (oget (assoc cvs j)).`1 i j by smt().
       by elim H4 => i j H4; exists (i,j) => /#.
     elim H3 => ch; progress.
     have ->: 1%r - inv ((factorial SS.n %/ (2 * factorial (SS.n - 2)))%r) = mu challenge_distr (fun (x : challenge_t) => x <> ch).
       rewrite mu_not.
       have ->: weight Top.InTheHead.challenge_distr = 1%r by smt.
       have ->: mu Top.InTheHead.challenge_distr (transpose (=) ch) = 
                mu1 Top.InTheHead.challenge_distr ch by congr.
       by rewrite challenge_distr1 => /#.
     rewrite mu_sub.
     rewrite /(<=) => /> r; progress.
     move : H8; rewrite /check /=; progress.
     move : H4 H5 H6 H8; elim r => i j /=.
     have H5: exists (vosi, vosj), (vosi, vosj) = 
             (mgen_response cvs x{hr} c (i, j))
               by exists ((mgen_response cvs x{hr} c (i, j))).`1
                         ((mgen_response cvs x{hr} c (i, j))).`2 => /#.
     elim H5 => vosi vosj H5; rewrite -H5 /=; move : H5.
     elim vosi => vi osi /=.
     elim vosj => vj osj /=.
     elim vi => xi ri tri /=.
     elim vj => xj rj trj /=.
     progress.
     case ((i,j) = ch) => H13.
       have H14 : !consistent_views_public relc x{hr} (xi, ri, tri) (xj, rj, trj) i j.
         have : verify ((xi, ri, tri)) (oget (assoc c i), osi) by smt().
         have : verify ((xj, rj, trj)) (oget (assoc c j), osj) by smt().
         progress. move : H6 H8; rewrite H10 H11 /=; progress. 
move : H9; rewrite /challenge /=.
rewrite /get_party_commitment /=.
smt().

move : H9; rewrite /challenge /=.
rewrite /get_party_commitment /=.
rewrite H14.
smt().
done.
   qed.

    lemma soundness &m x :
      Pr [ Soundness(RV,MProver(MPL)).main(x) @ &m : res ] <= 1%r - (1%r / (factorial SS.n %/ (2 * factorial (SS.n - 2)))%r) + Pr [ Binding.Game(B(RV,MPL)).main(x) @ &m : res] + Pr [ Binding.Game(C(RV,MPL)).main(x) @ &m : res]. 
    proof.
      have ?: Pr [ Soundness(RV,MProver(MPL)).main(x) @ &m : res ] <= Pr [ Game1(RV,MPL).main(x) @ &m : res ] + Pr [ Binding.Game(B(RV,MPL)).main(x) @ &m : res] by smt(game_game1_pr bad1_pr).
      have ?: Pr [ Game1(RV,MPL).main(x) @ &m : res ] <= Pr [ Game2(RV,MPL).main(x) @ &m : res ] + Pr [ Binding.Game(C(RV,MPL)).main(x) @ &m : res] by smt(game1_game2_pr bad2_pr).
      by smt(game2_pr).
    qed.

  end section Soundness.

end InTheHead.
