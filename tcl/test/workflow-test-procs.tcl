ad_library {
  Test cases for the Tcl API of the workflow package. The test cases are based 
  on the acs-automated-testing package.

  @author Peter Marklund
  @creation-date 10 January 2003
  @cvs-id $Id$
}

namespace eval workflow::test {}

ad_proc workflow::test::bug_workflow_name {} {
    The short name used for the Bug Tracker Bug test
    workflow. It is assumed this short name will not be
    present in the system.
} {
    return "bug_test"
}

ad_proc workflow::test::bug_workflow_object_id {} {

} {
    return [db_string main_site_package_id {select object_id
                                                              from site_nodes
                                                              where parent_id is null}]
}

ad_proc workflow::test::workflow_setup {} {
    Create a test workflow for the Bug Tracker 
    Bug use case.
} {
    #####
    #
    # Workflow
    #
    #####

    set main_site_package_id [workflow::test::bug_workflow_object_id]
    # Cannot use bt_bug as we cannot assume Bug Tracker to be installed
    # TODO: test side_effects?
    #            -side_effects { bug-tracker.FormatLogTitle } 
    set workflow_id [workflow::add \
            -short_name [workflow::test::bug_workflow_name] \
            -pretty_name "Bug Test" \
            -object_id $main_site_package_id \
            -object_type "acs_object"]

    #####
    #
    # Roles
    #
    #####

    # TODO: add assignment rules?
    #            -assignment_rules { workflow.CreationUser }
    workflow::role::add -workflow_id $workflow_id \
            -short_name "submitter" \
            -pretty_name "Submitter"

    # TODO: add assignment rules?
    #       -assignment_rules {
    #        bug-tracker.ComponentMaintainer
    #        bug-tracker.ProjectMaintainer
    #        }
    workflow::role::add -workflow_id $workflow_id \
            -short_name "assignee" \
            -pretty_name "Assignee"

    #####
    #
    # States
    #
    #####

    workflow::fsm::state::add -workflow_id $workflow_id \
            -short_name "open" \
            -pretty_name "Open"
    
    workflow::fsm::state::add -workflow_id $workflow_id \
            -short_name "resolved" \
            -pretty_name "Resolved"
    
    workflow::fsm::state::add -workflow_id $workflow_id \
            -short_name "closed" \
            -pretty_name "Closed"

    #####
    #
    # Actions
    #
    #####

    workflow::fsm::action::add -workflow_id $workflow_id \
            -short_name "comment" \
            -pretty_name "Comment" \
            -pretty_past_tense "Commented" \
            -allowed_roles { submitter assignee } \
            -privileges { read }

    workflow::fsm::action::add -workflow_id $workflow_id \
            -short_name "edit" \
            -pretty_name "Edit" \
            -pretty_past_tense "Edited" \
            -allowed_roles { submitter assignee } \
            -privileges { write }

    # TODO add side effects?
    #            -side_effects { bug-tracker.CaptureResolutionCode }
    workflow::fsm::action::add -workflow_id $workflow_id \
            -short_name "resolve" \
            -pretty_name "Resolve" \
            -pretty_past_tense "Resolved" \
            -assigned_role { assignee } \
            -enabled_states { open resolved } \
            -new_state "resolved" \
            -privileges { write }

    workflow::fsm::action::add -workflow_id $workflow_id \
            -short_name "close" \
            -pretty_name "Close" \
            -pretty_past_tense "Closed" \
            -assigned_role { submitter } \
            -enabled_states { resolved } \
            -new_state "closed" \
            -privileges { write }

    workflow::fsm::action::add -workflow_id $workflow_id \
            -short_name "reopen" \
            -pretty_name "Reopen" \
            -pretty_past_tense "Closed" \
            -allowed_roles { submitter } \
            -enabled_states { resolved closed } \
            -new_state "open" \
            -privileges { write }    
}

ad_proc workflow::test::workflow_teardown {} {
    Delete the Bug Tracker Bug test workflow.
} {
    set workflow_id [workflow::get_id -object_id [workflow::test::bug_workflow_object_id] \
                                      -short_name [workflow::test::bug_workflow_name]]

    workflow::delete -workflow_id $workflow_id
}

aa_register_case bugtracker_workflow_create {
    Test creation and teardown of an FSM workflow.

    @author Peter Marklund
    @creation-date 10 January 2003
} {
    # Make sure to run the teardown proc even if there is an error
    #set error_p [catch workflow::test::workflow_setup error]
    workflow::test::workflow_setup

    # Any assertions here?

    workflow::test::workflow_teardown

    # Any assertions here?

    # Report any errors from the setup proc
    #global errorInfo
    #aa_false "error during setup: $error - $errorInfo" $error_p
}
