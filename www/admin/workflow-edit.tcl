ad_page_contract {

    Workflow Edit page

    @author        Jeff Wang (jeff@ctrl.ucla.edu)
    @creation-date 3/17/2005

    @cvs-id  $Id$
} {
    {return_url [get_referrer]}
    {workflow_id:naturalnum,notnull}
}

set title "Workflow Edit"

workflow::get -workflow_id $workflow_id -array "wf_info"
set context [list $wf_info(short_name)]

db_multirow -extend {edit_url delete_url} get_states get_states {} {
    set edit_url [export_vars -base state-ae {state_id workflow_id}]
    workflow::state::fsm::get \
	    -state_id $state_id \
	    -array "state_info"
    set msg "You are about to delete $state_info(pretty_name). Are you sure?"
    set delete_url [export_vars {{id $state_id} {type state} msg}]
}

db_multirow -extend {edit_url delete_url} get_actions get_actions {} {
    set edit_url [export_vars -base action-ae {action_id workflow_id}]
    workflow::action::fsm::get \
	    -action_id $action_id \
	    -array "action_info"
    set msg "You are about to delete $action_info(pretty_name). Are you sure?"
    set delete_url [export_vars -base delete-confirm {{id $action_id} {type action} msg}]
}


db_multirow -extend {edit_url delete_url} get_roles get_roles {} {
    set edit_url [export_vars -base role-ae {role_id workflow_id}]
    workflow::role::get \
	     -role_id $role_id \
	    -array "role_info"
    set msg "You are about to delete $role_info(pretty_name). Are you sure?"
    set delete_url [export_vars -base delete-confirm {{id $role_id} msg {type role}}]
}

set wf_meta_edit   [export_vars -base workflow-ae {workflow_id}]
set add_role_url   [export_vars -base role-ae {workflow_id}]
set add_state_url  [export_vars -base state-ae {workflow_id}]
set add_action_url [export_vars -base action-ae {workflow_id}]


