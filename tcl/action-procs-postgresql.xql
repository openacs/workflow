<?xml version="1.0"?>
<queryset>
  <rdbms><type>postgresql</type><version>7.2</version></rdbms>

  <fullquery name="workflow::action::new.insert_action">
    <querytext>
        insert into workflow_actions
            (action_id, workflow_id, sort_order, short_name, pretty_name, pretty_past_tense, 
             edit_fields, assigned_role, always_enabled_p, description, description_mime_type, timeout)
      values (:action_id, :workflow_id, :sort_order, :short_name, :pretty_name, :pretty_past_tense, 
              :edit_fields, :assigned_role_id, :always_enabled_p, :description, :description_mime_type, 
              [ad_decode $timeout_seconds "" "null" "interval '$timeout_seconds seconds'"])
    </querytext>
  </fullquery>

  <partialquery name="workflow::action::edit.update_timeout_seconds">
    <querytext>
      timeout = [ad_decode $attr_timeout_seconds "" "null" "interval '$attr_timeout_seconds seconds'"]
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
               a.assigned_role,
               (select short_name from workflow_roles where role_id = a.assigned_role) as assigned_role_short_name,
               a.always_enabled_p,
               (select case when count(*) = 1 then 't' else 'f' end 
                from   workflow_initial_action 
                where  workflow_id = a.workflow_id 
                and    action_id = a.action_id
               ) as initial_action_p,
               fa.new_state as new_state_id,
               (select short_name from workflow_fsm_states where state_id = fa.new_state) as new_state,
               a.description,
               a.description_mime_type
        from   workflow_actions a left outer join 
               workflow_fsm_actions fa on (a.action_id = fa.action_id) 
        where  a.workflow_id = :workflow_id
          and  fa.action_id = a.action_id
        order by a.sort_order
    </querytext>
 </fullquery>
 
  <fullquery name="workflow::action::callback_insert.select_sort_order">
    <querytext>
        select coalesce(max(sort_order),0) + 1
        from   workflow_action_callbacks
        where  action_id = :action_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::action::edit.insert_allowed_role">
    <querytext>
        insert into workflow_action_allowed_roles
        select :action_id,
                (select role_id
                from workflow_roles
                where workflow_id = :workflow_id
                and short_name = :allowed_role) as role_id
    </querytext>
  </fullquery>


</queryset>
