<?xml version="1.0"?>
<queryset>
  <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

  <partialquery name="workflow::action::edit.update_timeout_seconds_name">
    <querytext>
      timeout_seconds
    </querytext>
  </partialquery>

  <partialquery name="workflow::action::edit.update_timeout_seconds_value">
    <querytext>
      :attr_timeout_seconds
    </querytext>
  </partialquery>

  <fullquery name="workflow::action::get_all_info_not_cached.action_info">
    <querytext>
        select a.action_id,
               a.workflow_id,
               a.sort_order,
               a.short_name,
               a.pretty_name,
               a.pretty_past_tense,
               a.edit_fields,
               a.trigger_type,
               a.parent_action_id,
               (select short_name from workflow_actions where action_id = a.parent_action_id) as parent_action,
               a.assigned_role as assigned_role_id,
               (select short_name from workflow_roles where role_id = a.assigned_role) as assigned_role,
               a.always_enabled_p,
               fa.new_state as new_state_id,
               (select short_name from workflow_fsm_states where state_id = fa.new_state) as new_state,
               a.description,
               a.description_mime_type,
               a.timeout_seconds
        from   workflow_actions a,
               workflow_fsm_actions fa
        where  a.workflow_id = :workflow_id
          and  a.action_id = fa.action_id (+)
        order by a.sort_order
    </querytext>
 </fullquery>

</queryset>
