<?xml version="1.0"?>
<queryset>

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
             assigned_role, always_enabled_p)
      values (:action_id, :workflow_id, :sort_order, :short_name, :pretty_name, :pretty_past_tense, 
              :assigned_role_id, :always_enabled_p)
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
        select workflow_id,
               sort_order,
               short_name,
               pretty_name,
               pretty_past_tense,
               assigned_role,
               always_enabled_p
        from workflow_actions
        where action_id = :action_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::callback_insert.select_sort_order">
    <querytext>
        select coalesce(max(sort_order)) + 1
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
        insert into workflow_fsm_action_enabled_in_states
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

</queryset>
