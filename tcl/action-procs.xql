<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::action::add.insert_allowed_role">
    <querytext>
        insert into workflow_action_allowed_roles
        select :action_id,
                (select role_id
                from workflow_roles
                where workflow_id = :workflow_id
                and short_name = :allowed_role) as role_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::add.insert_privilege">
    <querytext>
        insert into workflow_action_privileges
                (action_id, privilege)
         values (:action_id, :privilege)
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

  <fullquery name="workflow::action::add.insert_action">
    <querytext>
        insert into workflow_actions
         select  :action_id,
                 :workflow_id, 
                 :sort_order, 
                 :short_name, 
                 :pretty_name, 
                 :pretty_past_tense, 
                 :assigned_role_id,
                 :always_enabled_p
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
