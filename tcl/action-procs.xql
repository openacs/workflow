<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::action::new.select_sort_order_p">
    <querytext>
        select count(*)
        from   workflow_actions
        where  workflow_id = :workflow_id
        and    sort_order = :sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::new.update_sort_order">
    <querytext>
        update workflow_actions
        set    sort_order = sort_order + 1
        where  workflow_id = :workflow_id
        and    sort_order >= :sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::new.insert_allowed_role">
    <querytext>
        insert into workflow_action_allowed_roles
        select :action_id,
                (select role_id
                from workflow_roles
                where workflow_id = :workflow_id
                and short_name = :allowed_role) as role_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::new.insert_privilege">
    <querytext>
        insert into workflow_action_privileges
                (action_id, privilege)
         values (:action_id, :privilege)
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::new.insert_action">
    <querytext>
        insert into workflow_actions
            (action_id, workflow_id, sort_order, short_name, pretty_name, pretty_past_tense, 
             edit_fields, assigned_role, always_enabled_p)
      values (:action_id, :workflow_id, :sort_order, :short_name, :pretty_name, :pretty_past_tense, 
              :edit_fields, :assigned_role_id, :always_enabled_p)
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::new.insert_initial_action">
    <querytext> 
        insert into workflow_initial_action
                (workflow_id, action_id)
         values (:workflow_id, :action_id)
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_all_info_not_cached.select_privileges">
    <querytext>
      select p.privilege,
             p.action_id
      from   workflow_action_privileges p,
             workflow_actions a
      where  a.action_id = p.action_id
        and  a.workflow_id = :workflow_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_all_info_not_cached.action_info">
    <querytext>
        select a.action_id,
               a.workflow_id,
               a.sort_order,
               a.short_name,
               a.pretty_name,
               a.pretty_past_tense,
               a.edit_fields,
               a.assigned_role,
               (select short_name from workflow_roles where role_id = a.assigned_role) as assigned_role_short_name,
               a.always_enabled_p,
               (select case when count(*) = 1 then 't' else 'f' end 
                from   workflow_initial_action 
                where  workflow_id = a.workflow_id 
                and    action_id = a.action_id
               ) as initial_action_p,
               fa.new_state as new_state_id,
               (select short_name from workflow_fsm_states where state_id = fa.new_state) as new_state
        from   workflow_actions a left outer join 
               workflow_fsm_actions fa on (a.action_id = fa.action_id) 
        where  a.workflow_id = :workflow_id
          and  fa.action_id = a.action_id
        order by a.sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_workflow_id_not_cached.select_workflow_id">
    <querytext>
        select workflow_id
        from workflow_actions
        where action_id = :action_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_all_info_not_cached.action_callbacks">
    <querytext>
      select impl.impl_id,
             impl.impl_name,
             impl.impl_owner_name,
             ctr.contract_name,
             a.action_id
      from   workflow_action_callbacks ac,
             workflow_actions a,
             acs_sc_impls impl,
             acs_sc_bindings bind,
             acs_sc_contracts ctr
      where  ac.action_id = a.action_id
      and    a.workflow_id = :workflow_id
      and    impl.impl_id = ac.acs_sc_impl_id
      and    impl.impl_id = bind.impl_id
      and    bind.contract_id = ctr.contract_id
      order  by a.action_id, ac.sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_all_info_not_cached.action_allowed_roles">
    <querytext>
      select r.short_name,
             r.role_id,
             aar.action_id
      from   workflow_roles r,
             workflow_action_allowed_roles aar
      where  r.workflow_id = :workflow_id
      and    r.role_id = aar.role_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_all_info_not_cached.action_enabled_short_name">
    <querytext>
        select s.short_name,
               waeis.action_id
        from   workflow_fsm_action_en_in_st waeis,
               workflow_actions a,
               workflow_fsm_states s
        where  waeis.action_id = a.action_id
        and    a.workflow_id = :workflow_id
        and    s.state_id = waeis.state_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::callback_insert.select_sort_order">
    <querytext>
        select coalesce(max(sort_order),0) + 1
        from   workflow_action_callbacks
        where  action_id = :action_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::callback_insert.insert_callback">
    <querytext>
        insert into workflow_action_callbacks (action_id, acs_sc_impl_id, sort_order)
        values (:action_id, :acs_sc_impl_id, :sort_order)
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::fsm::new.insert_fsm_action">
    <querytext>
        insert into workflow_fsm_actions
                (action_id, new_state)
            values
                (:action_id, :new_state_id)        
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::fsm::new.insert_enabled_state">
    <querytext>
        insert into workflow_fsm_action_en_in_st
                (action_id, state_id)
         values (:action_id, :enabled_state_id)
    </querytext>
  </fullquery>

</queryset>
