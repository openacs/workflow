ad_library {
  Test cases for the Tcl API of the workflow package. The test cases are based 
  on the acs-automated-testing package.

  @author Peter Marklund
  @creation-date 10 January 2003
  @cvs-id $Id$
}

namespace eval workflow::test {}

ad_proc workflow::test::workflow_name {} {
    The short name used for the Bug Tracker Bug test
    workflow. It is assumed this short name will not be
    present in the system.
} {
    return "bug_test"
}

ad_proc workflow::test::workflow_object_id {} {

} {
    return [db_string main_site_package_id {select object_id
                                                              from site_nodes
                                                              where parent_id is null}]
}

ad_proc workflow::test::workflow_id {} {
    Get the id of the Bug Tracker bug workflow
} {
    return [workflow::get_id -object_id [workflow::test::workflow_object_id] \
                                      -short_name [workflow::test::workflow_name]]
}

ad_proc workflow::test::admin_owner_id {} {
    Return the id of the site-wide-admin (the only person
    guaranteed to be on the system).
} {
    set admin_email [ad_admin_owner]

    return [db_string admin_owner_id "select party_id from parties where email = :admin_email"]
}

ad_proc workflow::test::action_short_names { action_id_list } {

    Return the short names of the actions with given id:s
} {
    set short_name_list [list]
    foreach action_id $action_id_list {
        array set action_info [workflow::action::get -action_id $action_id]

        lappend short_name_list $action_info(short_name)
    }

    return $short_name_list
}

ad_proc workflow::test::assert_case_state {
    {-workflow_id:required}
    {-case_id:required}
    {-expect_current_state:required}
    {-expect_enabled_actions:required} 
    {-expect_user_actions:required} 
    {-expect_user_roles:required}
    
} {
    Make assertions about what the current state should be and
    what actions are enabled etc.
} {

    set user_roles \
      [workflow::case::get_user_roles -case_id $case_id \
                                      -user_id [workflow::test::admin_owner_id]]
    set enabled_actions [workflow::test::action_short_names \
            [workflow::case::get_enabled_actions -case_id $case_id]]
    array set state_info \
            [workflow::state::fsm::get -state_id [workflow::case::fsm::get_current_state -case_id $case_id]]
    set user_actions [workflow::test::action_short_names \
            [workflow::case::get_user_actions -case_id $case_id \
                                                     -user_id [workflow::test::admin_owner_id]]]

    aa_true "current state should be $expect_current_state" \
            [string equal $state_info(short_name) $expect_current_state]
    aa_true "checking enabled actions ($enabled_actions) in $expect_current_state state, expecting ($expect_enabled_actions)" \
            [util_sets_equal_p $enabled_actions $expect_enabled_actions]
    aa_true "checking user actions ($user_actions) in $expect_current_state state, expecting ($expect_user_actions)" \
            [util_sets_equal_p $user_actions $expect_user_actions]
    aa_true "user not assigned to any roles yet" \
            [empty_string_p $user_roles]
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

    set main_site_package_id [workflow::test::workflow_object_id]
    # Cannot use bt_bug as we cannot assume Bug Tracker to be installed
    # TODO: test side_effects?
    #            -side_effects { bug-tracker.FormatLogTitle } 
    set workflow_id [workflow::new \
            -short_name [workflow::test::workflow_name] \
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
    workflow::role::new -workflow_id $workflow_id \
            -short_name "submitter" \
            -pretty_name "Submitter"

    # TODO: add assignment rules?
    #       -assignment_rules {
    #        bug-tracker.ComponentMaintainer
    #        bug-tracker.ProjectMaintainer
    #        }
    workflow::role::new -workflow_id $workflow_id \
            -short_name "assignee" \
            -pretty_name "Assignee"

    #####
    #
    # States
    #
    #####

    workflow::state::fsm::new -workflow_id $workflow_id \
            -short_name "open" \
            -pretty_name "Open"
    
    workflow::state::fsm::new -workflow_id $workflow_id \
            -short_name "resolved" \
            -pretty_name "Resolved"
    
    workflow::state::fsm::new -workflow_id $workflow_id \
            -short_name "closed" \
            -pretty_name "Closed"

    #####
    #
    # Actions
    #
    #####

    workflow::action::fsm::new -initial_action \
                              -workflow_id $workflow_id \
                              -short_name "open" \
                              -pretty_name "Open" \
                              -pretty_past_tense "Opened" \
                              -new_state "open"                              

    workflow::action::fsm::new -workflow_id $workflow_id \
            -short_name "comment" \
            -pretty_name "Comment" \
            -pretty_past_tense "Commented" \
            -allowed_roles { submitter assignee } \
            -privileges { read } \
            -always_enabled_p t

    workflow::action::fsm::new -workflow_id $workflow_id \
            -short_name "edit" \
            -pretty_name "Edit" \
            -pretty_past_tense "Edited" \
            -allowed_roles { submitter assignee } \
            -privileges { write } \
            -always_enabled_p t

    # TODO add side effects?
    #            -side_effects { bug-tracker.CaptureResolutionCode }
    workflow::action::fsm::new -workflow_id $workflow_id \
            -short_name "resolve" \
            -pretty_name "Resolve" \
            -pretty_past_tense "Resolved" \
            -assigned_role { assignee } \
            -enabled_states { open resolved } \
            -new_state "resolved" \
            -privileges { write }

    workflow::action::fsm::new -workflow_id $workflow_id \
            -short_name "close" \
            -pretty_name "Close" \
            -pretty_past_tense "Closed" \
            -assigned_role { submitter } \
            -enabled_states { resolved } \
            -new_state "closed" \
            -privileges { write }

    workflow::action::fsm::new -workflow_id $workflow_id \
            -short_name "reopen" \
            -pretty_name "Reopen" \
            -pretty_past_tense "Closed" \
            -allowed_roles { submitter } \
            -enabled_states { resolved closed } \
            -new_state "open" \
            -privileges { write }    

    return $workflow_id
}

ad_proc workflow::test::workflow_teardown {} {
   Delete the Bug Tracker Bug test workflow.
} {
   set workflow_id [workflow::get_id -object_id [workflow::test::workflow_object_id] \
                                     -short_name [workflow::test::workflow_name]]

   workflow::delete -workflow_id $workflow_id
}


ad_proc workflow::test::case_setup {} {
    Create a case of the Bug Tracker bug test workflow.

    @author Peter Marklund
} {
    set workflow_id [workflow::test::workflow_id]
    
    set case_id [workflow::case::new -workflow_id $workflow_id \
                                     -object_id [workflow::test::workflow_object_id] \
                                     -comment "Test workflow case" \
                                     -comment_format "plain" \
                                     -user_id [workflow::test::admin_owner_id]]

    return $case_id
}

aa_register_case bugtracker_workflow_create {
    Test creation and teardown of an FSM workflow case.

    @author Peter Marklund
    @creation-date 16 January 2003
} {
    # Setup
    # Make sure to run the teardown proc even if there is an error
    # Cannot get this to work as it seems the catch will return true
    # if any catch did so in the executed code.
    # set error_p [catch workflow::test::workflow_setup error]
    set workflow_id [workflow::test::workflow_setup]

    # Create the workflow case in open state
    set object_id [workflow::test::workflow_object_id]
    set case_id [workflow::test::case_setup]

    set retrieved_case_id \
      [workflow::case::get_id -object_id $object_id \
                              -workflow_short_name [workflow::test::workflow_name]]
    set retrieved_object_id \
      [workflow::case::get_object_id -case_id $case_id]
    aa_true "case_id of a created workflow case should be retrievable" \
            [string equal $case_id $retrieved_case_id]
    aa_true "object_id of a created workflow case should be retrievable" \
            [string equal $object_id $retrieved_object_id]

    set expect_enabled_actions [list comment edit resolve]
    workflow::test::assert_case_state -workflow_id $workflow_id \
                                      -case_id $case_id \
                                      -expect_current_state open \
                                      -expect_enabled_actions $expect_enabled_actions \
                                      -expect_user_actions $expect_enabled_actions \
                                      -expect_user_roles {}

    # Resolve the bug
    workflow::case::action::execute -case_id $case_id \
                                    -action_id [workflow::action::get_id -workflow_id $workflow_id \
                                                                         -short_name "resolve"] \
                                    -comment "Resolving Bug" \
                                    -comment_format plain \
                                    -user_id [workflow::test::admin_owner_id]

    set expect_enabled_actions [list comment edit resolve reopen close]
    workflow::test::assert_case_state -workflow_id $workflow_id \
                                      -case_id $case_id \
                                      -expect_current_state resolved \
                                      -expect_enabled_actions $expect_enabled_actions \
                                      -expect_user_actions $expect_enabled_actions \
                                      -expect_user_roles {}
                              
    # Close the bug
    workflow::case::action::execute -case_id $case_id \
                                    -action_id [workflow::action::get_id -workflow_id $workflow_id \
                                                                         -short_name "close"] \
                                    -comment "Closing Bug" \
                                    -comment_format plain \
                                    -user_id [workflow::test::admin_owner_id]

    set expect_enabled_actions [list comment edit reopen]
    workflow::test::assert_case_state -workflow_id $workflow_id \
                                      -case_id $case_id \
                                      -expect_current_state closed \
                                      -expect_enabled_actions $expect_enabled_actions \
                                      -expect_user_actions $expect_enabled_actions \
                                      -expect_user_roles {}    

    # Teardown
    workflow::test::workflow_teardown

    # Report any errors from the setup proc
    #global errorInfo
    #aa_false "error during setup: $error - $errorInfo" $error_p
}
