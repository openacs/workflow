<?xml version="1.0"?>
<queryset>
  <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

  <fullquery name="workflow::case::role::get_assignees_not_cached.select_assignees">
    <querytext>
        select m.party_id, 
               p.email,
               acs_object.name(m.party_id) as name
        from   workflow_case_role_party_map m,
               parties p
        where  m.case_id = :case_id
        and    m.role_id = :role_id
        and    p.party_id = m.party_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::notify.select_object_name">
    <querytext>
        select acs_object.name(:object_id) as name from dual
    </querytext>
   </fullquery>

  <partialquery name="workflow::case::role::get_search_query.select_search_results">
    <querytext>
        select distinct acs_object.name(p.party_id) || ' (' || p.email || ')' as label, p.party_id
        from   [ad_decode $subquery "" "cc_users" $subquery] p
        where  upper(nvl(acs_object.name(p.party_id) || ' ', '')  || p.email) like upper('%'||:value||'%')
        order  by label
    </querytext>
  </partialquery>

  <fullquery name="workflow::case::role::get_picklist.select_options">
    <querytext>
        select acs_object.name(p.party_id) || ' (' || p.email || ')'  as label, p.party_id
        from   parties p
        where  p.party_id in ([join $party_id_list ", "])
        order  by label
    </querytext>
  </fullquery>

   <fullquery name="workflow::case::delete.delete_case">
    <querytext>
        begin
            :1 := workflow_case_pkg.del(:case_id);
        end;
    </querytext>
  </fullquery>

  <fullquery name="workflow::case::action::enable.insert_enabled">
    <querytext>
        insert into workflow_case_enabled_actions
              (enabled_action_id, 
               case_id, 
               action_id, 
               parent_enabled_action_id, 
               assigned_p, 
               execution_time)
        select :enabled_action_id, 
               :case_id, 
               :action_id, 
               :parent_enabled_action_id, 
               :db_assigned_p, 
               sysdate + a.timeout_seconds/(24*60*60)
        from   workflow_actions a
        where  a.action_id = :action_id
    </querytext>
  </fullquery>

</queryset>
