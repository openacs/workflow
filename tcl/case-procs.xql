<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::case::insert.insert_case">
    <querytext>
      insert into workflow_cases (
        case_id, workflow_id, object_id
      ) values (
        :case_id, :workflow_id, :object_id
      )      
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::insert.insert_case_fsm">
    <querytext>
      insert into workflow_case_fsm (
        case_id, current_state
      ) values (
        :case_id, null
      )
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::get_id.select_case_id">
    <querytext>
      select case_id
      from   workflow_cases c, 
             workflows w
      where  c.object_id = :object_id
      and    w.workflow_id = c.workflow_id
      and    w.short_name = :workflow_short_name
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::get_user_roles.select_user_roles">
    <querytext>
      select distinct rpm.role_id
      from   workflow_case_role_party_map rpm, 
             party_approved_member_map pmm
      where  rpm.case_id = :case_id
      and    rpm.party_id = pmm.party_id
      and    pmm.member_id = :user_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::get_enabled_actions.select_enabled_actions">
    <querytext>
      select a.action_id
      from   workflow_cases c,
             workflow_actions a
      where  c.case_id = :case_id
      and    a.workflow_id = c.workflow_id
      and    not exists (select 1 
                         from   workflow_initial_action wia
                         where  wia.workflow_id = c.workflow_id
                         and    wia.action_id = a.action_id)
      and    (a.always_enabled_p = 't' 
             or exists (select 1 
                        from   workflow_case_fsm cfsm,
                               workflow_fsm_action_en_in_st waeis
                        where  cfsm.case_id = c.case_id
                        and    waeis.state_id = cfsm.current_state
                        and    waeis.action_id = a.action_id))
      order by a.sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::assign_roles.select_num_assignees">
    <querytext>
      select count(*)
      from   workflow_case_role_party_map
      where  case_id = :case_id
      and    role_id = :role_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::role::get_callbacks.select_callbacks">
    <querytext>
      select impl.impl_name
      from   workflow_role_callbacks r,
             acs_sc_impls impl,
             acs_sc_bindings bind,
             acs_sc_contracts ctr
      where  r.role_id = :role_id
      and    impl.impl_id = r.acs_sc_impl_id
      and    impl.impl_id = bind.impl_id
      and    bind.contract_id = ctr.contract_id
      and    ctr.contract_name = :contract_name
      order  by r.sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::role::get_picklist.select_options">
    <querytext>
        select acs_object__name(p.party_id) || ' (' || p.email || ')'  as label, p.party_id
        from   parties p
        where  p.party_id in ([join $party_id_list ", "])
        order  by label
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::role::assignee_insert.delete_assignees">
    <querytext>
        delete from workflow_case_role_party_map
        where  case_id = :case_id
        and    role_id = :role_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::role::assignee_insert.insert_assignee">
    <querytext>
      insert into workflow_case_role_party_map
        (case_id, role_id, party_id)
      values
        (:case_id, :role_id, :party_id)
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::role::assignee_insert.already_assigned_p">
    <querytext>
      select count(*)
      from   workflow_case_role_party_map
      where  case_id = :case_id
      and    role_id = :role_id
      and    party_id = :party_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::fsm::get_current_state.select_current_state">
    <querytext>
      select current_state
      from   workflow_case_fsm c
      where  c.case_id = :case_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::fsm::get.select_case_info">
    <querytext>
      select c.case_id,
             c.workflow_id,
             c.object_id,
             s.state_id,
             s.short_name as state_short_name,
             s.pretty_name as pretty_state,
             s.hide_fields as state_hide_fields
      from   workflow_cases c,
             workflow_case_fsm cfsm,
             workflow_fsm_states s
      where  c.case_id = :case_id
      and    cfsm.case_id = c.case_id
      and    s.state_id = cfsm.current_state
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::fsm::get.select_case_info_after_action">
    <querytext>
      select c.case_id,
             c.workflow_id,
             c.object_id,
             s.state_id,
             s.short_name as state_short_name,
             s.pretty_name as pretty_state,
             s.hide_fields as state_hide_fields
      from   workflow_cases c,
             workflow_case_fsm cfsm,
             workflow_fsm_states s,
             workflow_fsm_actions a
      where  c.case_id = :case_id
      and    cfsm.case_id = c.case_id
      and    a.action_id = :action_id
      and    ((a.new_state is null and s.state_id = cfsm.current_state)  or (s.state_id = a.new_state))
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::enabled_p.select_enabled_p">
    <querytext>
      select 1
      from   workflow_actions a
      where  a.action_id = :action_id
      and    (a.always_enabled_p = 't' or 
             exists (select 1 
                     from   workflow_fsm_action_en_in_st waeis,
                            workflow_case_fsm c_fsm
                     where  waeis.action_id = a.action_id
                     and    c_fsm.case_id = :case_id
                     and    waeis.state_id = c_fsm.current_state)
             )
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::execute.update_fsm_state">
    <querytext>
      update workflow_case_fsm
      set    current_state = :new_state_id
      where  case_id = :case_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::execute.log_entry_exists_p">
    <querytext>
        select count(*)
        from   cr_revisions
        where  revision_id = :entry_id
    </querytext>
  </fullquery>

</queryset>
