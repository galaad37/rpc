From aneris.aneris_lang Require Import lang.
From aneris.aneris_lang.program_logic Require Import aneris_weakestpre.
From aneris.aneris_lang.lib
     Require Import lock_proof monitor_proof serialization_proof.
From aneris.examples.reliable_communication.lib.reliable_rpc
     Require Import params reliable_rpc_code.

Section Spec.
	Context `{ !anerisG Mdl Σ, !lockG Σ}.
	Context `{ !RPC_user_params }.
	Context `{ IP : !@RPC_interface_params Σ }.
	Context (SrvInit : iProp Σ).
	Context (srv_si : message → iProp Σ).
	Notation srv_ip := (ip_of_address RPC_saddr).

	Context (LockedChannel : val → socket_address → iProp Σ).

	Definition implement_spec {RP : RPC_rpc_params} (IMP : RPC_implementation_params RP) : iProp Σ :=
		{{{ ⌜In RP IP⌝ }}}
			implement IMP.(RPC_val) IMP.(RPC_handler) @[srv_ip]
		{{{ h, RET (#RP.(RPC_name), h)%V; ⌜is_impl_handler_of_rpc h RP⌝ }}}.

	Definition init_server_stub_spec (II : RPC_interface_implementation IP) : iProp Σ :=
		∀ A,
		{{{ RPC_saddr ⤇ srv_si ∗
				fixed A ∗
				⌜RPC_saddr ∈ A⌝ ∗
				RPC_saddr ⤳ (∅, ∅) ∗
				free_ports (srv_ip) {[port_of_address RPC_saddr]} ∗
				SrvInit }}}
			init_server_stub #RPC_saddr II.(RPC_inter_val) @[srv_ip]
		{{{ RET #(); ⌜True⌝ }}}.

	Definition init_client_stub_spec : iProp Σ :=
		∀ A clt_addr,
		{{{ RPC_saddr ⤇ srv_si ∗
				fixed A ∗
				⌜clt_addr ∉ A⌝ ∗
				clt_addr ⤳ (∅, ∅) ∗
				free_ports (ip_of_address clt_addr) {[port_of_address clt_addr]} }}}
			init_client_stub #clt_addr #RPC_saddr @[ip_of_address clt_addr]
		{{{ chan, RET chan; LockedChannel chan clt_addr }}}.

	Definition rpc_spec {RP : RPC_rpc_params} (f : val) clt_addr : iProp Σ :=
		∀ argv argd,
		{{{ RP.(RPC_pre) argv argd }}}
			f argv @[ip_of_address clt_addr]
		{{{ repv repd, RET repv; RP.(RPC_post) repv argd repd }}}.

	Definition call_spec {RP : RPC_rpc_params} (IMP : RPC_implementation_params RP) : iProp Σ :=
		∀ chan clt_addr,
		{{{ ⌜In RP IP⌝ ∗ LockedChannel chan clt_addr }}}
			call chan IMP.(RPC_val) @[ip_of_address clt_addr]
		{{{ f, RET f; @rpc_spec RP f clt_addr }}}.

End Spec.


Section RPC_Init.

	Context `{ !anerisG Mdl Σ, !lockG Σ}.
	Check call_spec.
	Class RPC_init := {
		RPC_init_setup E (UP : RPC_user_params) (IP : RPC_interface_params) :
		↑RPC_mN ⊆ E →
    ⊢ |={E}=> ∃ (srv_si : message → iProp Σ) (SrvInit : iProp Σ)
								(LockedChannel : val → socket_address → iProp Σ),
			SrvInit ∗
			(∀ (II : RPC_interface_implementation IP), 
				init_server_stub_spec SrvInit srv_si II) ∗
			(init_client_stub_spec srv_si LockedChannel) ∗
			( ∀ (RP : RPC_rpc_params) (IMP : RPC_implementation_params RP),
				@call_spec _ _ _ _ IP LockedChannel RP IMP)
	}.

Section RPC_Init.
