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

  <fullquery name="workflow::action::get_assigned_role.select_assigned_role">
    <querytext>
      select assigned_role
      from   workflow_actions
      where  action_id = :action_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_allowed_roles.select_allowed_roles">
    <querytext>
      select role_id
      from   workflow_action_allowed_roles
      where  action_id = :action_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_privileges.select_privileges">
    <querytext>
      select privilege
      from   workflow_action_privileges
      where  action_id = :action_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get_id.select_action_id">
    <querytext>
      select action_id
      from   workflow_actions
      where  workflow_id = :workflow_id
      and    short_name = :short_name
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get.action_info">
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
               ) as initial_action_p
        from   workflow_actions a
        where  a.action_id = :action_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get.action_callbacks">
    <querytext>
        select impl.impl_owner_name || '.' || impl.impl_name
        from   acs_sc_impls impl,
               workflow_action_callbacks c
        where  c.action_id = :action_id
        and    impl.impl_id = c.acs_sc_impl_id
        order  by c.sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::get.action_allowed_roles">
    <querytext>
      select r.short_name
      from   workflow_roles r,
             workflow_action_allowed_roles aar
      where  aar.action_id = :action_id
      and    r.role_id = aar.role_id
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

  <fullquery name="workflow::action::fsm::get_new_state.select_new_state">
    <querytext>
      select new_state
      from   workflow_fsm_actions a
      where  action_id = :action_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::fsm::get.action_fsm_info">
    <querytext>
        select a.new_state as new_state_id,
               s.short_name as new_state
        from   workflow_fsm_actions a,
               workflow_fsm_states s
        where  a.action_id = :action_id
        and    s.state_id = a.new_state
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::fsm::get.action_enabled_short_name">
    <querytext>
        select s.short_name
        from   workflow_fsm_action_en_in_st waeis,
               workflow_fsm_states s
        where  waeis.action_id = :action_id
        and    s.state_id = waeis.state_id
    </querytext>
  </fullquery>

</queryset>
