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

  <fullquery name="workflow::case::get_case_id.select_case_id">
    <querytext>
      select case_id
      from   workflow_cases c, 
             workflows w
      where  c.object_id = :case_object_id
      and    w.workflow_id = c.workflow_id
      and    w.short_name = :workflow_short_name
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::get_object_id.select_object_id">
    <querytext>
      select object_id
      from   workflow_cases c
      where  c.case_id = :case_id
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
      select distinct action_id
      from  (select waeis.action_id
             from   workflow_cases c,
                    workflow_case_fsm cfsm,
                    workflow_fsm_action_enabled_in_states waeis
             where  c.case_id = :case_id
             and    cfsm.case_id = c.case_id
             and    waeis.state_id = cfsm.state_id

             union

             select a.action_id
             from   workflow_cases c,
                    workflow_actions a
             where  c.case_id = :case_id
             and    a.workflow_id = c.workflow_id
             and    a.always_enabled_p = 't'
            )
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

  <fullquery name="workflow::case::role::set_default_assignees.select_assignment_rules">
    <querytext>
      select impl.impl_name
      from   workflow_role_assignment_rules r,
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

  <fullquery name="workflow::case::action::enabled_p.select_enabled_p">
    <querytext>
      select 1
      from   workflow_actions a
      where  a.action_id = :action_id
      and    a.always_enabled_p = 't' or 
             exists (select 1 
                     from   workflow_actions_enabled_in_states waeis,
                            workflow_cases_fsm c_fsm,
                     where  waeis.action_id = a.action_id
                     and    c_fsm.case_id = :case_id
                     and    waeis.state_id = c_fsm.current_state)
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::execute.update_fsm_state">
    <querytext>
      update workflow_case_fsm
      set    current_state = :new_state
      where  case_id = :case_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::execute.insert_log_entry">
    <querytext>
      insert into workflow_case_log 
        (entry_id, case_id, action_id, user_id, comment, comment_format)
      values
        (:entry_id, :case_id, :action_id, :user_id, :comment, :comment_format)
    </querytext>
  </fullquery>

</queryset>
