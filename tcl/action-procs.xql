<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::fsm::action::add.insert_enabled_state">
    <querytext>
        insert into workflow_actions
              (action_id, workflow_id, sort_order, short_name, 
               pretty_name, pretty_past_tense, assigned_role)
        values (:action_id, :workflow_id, :sort_order, :short_name,
               :pretty_name, :pretty_past_tense, :assigned_role)
    </querytext>
  </fullquery>

  <fullquery name="workflow::fsm::action::add.insert_allowed_role">
    <querytext>
        insert into workflow_action_allowed_roles
                (action_id, role_id)
         values (:action_id, :allowed_role)
    </querytext>
  </fullquery>

  <fullquery name="workflow::fsm::action::add.insert_action_privilege">
    <querytext>
        insert into workflow_action_privileges
                (action_id, privilege)
         values (:action_id, :privilege)
    </querytext>
  </fullquery>

</queryset>
