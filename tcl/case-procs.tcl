ad_library {
    Procedures in the case namespace.
    
    @creation-date 13 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::case {}
namespace eval workflow::case::fsm {}
namespace eval workflow::case::action {}
namespace eval workflow::case::role {}
namespace eval workflow::case::action::fsm {}

#####
#
#  workflow::case
#
#####

ad_proc -private workflow::case::insert {
    {-workflow_id:required}
    {-object_id:required}
} {
    Internal procedure that creates a new workflow case in the
    database. Should not be used by applications.

    @param object_id The object_id which the case is about
    @param workflow_short_name The short_name of the workflow.
    @return The case_id of the case. Returns the empty string if no case could be found.

    @see 

    @author Lars Pind (lars@collaboraid.biz)
} {
    set case_id [db_nextval "workflow_cases_seq"]

    db_transaction {
        # Create the case
        db_dml insert_case {}

        # Initialize the FSM state to NULL
        db_dml insert_case_fsm {}
    }
    
    return $case_id
}

ad_proc -public workflow::case::new {
    {-workflow_id:required}
    {-object_id:required}
    {-comment:required}
    {-comment_format:required}
    {-user_id}
} {
    Start a new case for this workflow and object.

    @param object_id The object_id which the case is about
    @param workflow_short_name The short_name of the workflow.
    @param comment_format html, plain or pre
    @return The case_id of the case. Returns the empty string if no case could be found.

    @author Lars Pind (lars@collaboraid.biz)
} {
    if { ![exists_and_not_null user_id] } {
        set user_id [ad_conn user_id]
    }
    
    db_transaction {

        ns_log Notice "LARS - case::new1: object_id = $object_id, [db_string foobar { select count(*) from acs_objects where object_id = :object_id }]"

        # Insert the case
        set case_id [insert -workflow_id $workflow_id -object_id $object_id]

        ns_log Notice "LARS - case::new2: object_id = $object_id, [db_string foobar { select count(*) from acs_objects where object_id = :object_id }]"

        # Execute the initial action
        workflow::case::action::execute \
                -case_id $case_id \
                -action_id [workflow::get_initial_action -workflow_id $workflow_id] \
                -comment $comment \
                -comment_format $comment_format \
                -user_id $user_id \
                -no_check

        ns_log Notice "LARS - case::new3: object_id = $object_id, [db_string foobar { select count(*) from acs_objects where object_id = :object_id }]"

    }
        
    return $case_id
}

ad_proc -public workflow::case::get_id {
    {-object_id:required}
    {-workflow_short_name:required}
} {
    Gets the case_id from the object_id which the case is about, 
    along with the short_name of the workflow.

    @param object_id The object_id which the case is about
    @param workflow_short_name The short_name of the workflow.
    @return The case_id of the case. Returns the empty string if no case could be found.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set found_p [db_0or1row select_case_id {}]
    if { $found_p } {
        return $case_id
    } else {
        error "No matching workflow case found for object_id $object_id and workflow_short_name $workflow_short_name"
    }
}

ad_proc -public workflow::case::get {
    {-case_id:required}
    {-array:required}
    {-action_id {}}
} {
    Get information about a case

    @param caes_id The case ID
    @param array The name of an array in which information will be returned.

    @author Lars Pind (lars@collaboraid.biz)
} {
    # Select the info into the upvar'ed Tcl Array
    upvar $array row

    workflow::case::fsm::get -case_id $case_id -array row -action_id $action_id

    # LARS TODO:
    # Should we redesign the API so that it's polymorphic, wrt. to workflow type (FSM/Petri Net)
    # That way, you'd call workflow::case::get and get a state_pretty pseudocolumn, which would be
    # the pretty-name of the state in an FSM, but it would be some kind of human-readable summary of
    # the active tokens in a petri net.
}

ad_proc -public workflow::case::get_element {
    {-case_id:required}
    {-element:required}
    {-action_id {}}
} {
    Return a single element from the information about a case.

    @param case_id The ID of the case
    @param element The element you want
    @return The element you asked for

    @author Lars Pind (lars@collaboraid.biz)
} {
    get -case_id $case_id -action_id $action_id -array row
    return $row($element)
}

ad_proc -public workflow::case::get_user_roles {
    {-case_id:required}
    -user_id
} {
    Get the roles which this user is assigned to
of 
    @param case_id     The ID of the case.
    @param user_id     The user_id of the user for which you want to know the roles.
    @return A list of role_id's of the roles which the user is assigned to in this case.

    @author Lars Pind (lars@collaboraid.biz)
} {
    if { ![exists_and_not_null user_id] } {
        set user_id [ad_conn user_id]
    }
    return [db_list select_user_roles {}]
}

ad_proc -public workflow::case::get_enabled_actions {
    {-case_id:required}
} {
    Get the currently enabled actions, based on the state of the case

    @param case_id     The ID of the case.
    @return            A list of id's of the actions which are currently 
                       enabled
                       
    @author Lars Pind (lars@collaboraid.biz)
} {
    return [db_list select_enabled_actions {}]
}

ad_proc -public workflow::case::get_available_actions {
    {-case_id:required}
    -user_id
} {
    Get the actions which are enabled and which the current user have permission to execute.

    @param case_id     The ID of the case.
    @return            A list of ID's of the available actions.

    @author Lars Pind (lars@collaboraid.biz)
} {
    if { ![exists_and_not_null user_id] } {
        set user_id [ad_conn user_id]
    }

    set action_list [list]

    foreach action_id [get_enabled_actions -case_id $case_id] {
        if { [workflow::case::action::permission_p -case_id $case_id -action_id $action_id -user_id $user_id] } {
            lappend action_list $action_id
        }
    }

    return $action_list
}

ad_proc -private workflow::case::assign_roles {
    {-case_id:required}
} {
    Find out which roles are assigned to currently enabled actions.
    If any of these currently have zero assignees, run the default 
    assignment process.
    
    @param case_id the ID of the case.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set role_id_list [list]

    foreach action_id [get_enabled_actions -case_id $case_id] {
        set role_id [workflow::action::get_assigned_role -action_id $action_id]
        if { ![empty_string_p $role_id] && [lsearch $role_id_list $role_id] == -1 } {
            lappend role_id_list $role_id
        }
    }

    foreach role_id $role_id_list {
        set num_assignees [db_string select_num_assignees {}]

        if { $num_assignees == 0 } {
            workflow::case::role::set_default_assignees \
                    -case_id $case_id \
                    -role_id $role_id
        }
    }
}





#####
#
# workflow::case::role namespace
#
#####

ad_proc -public workflow::case::role::set_default_assignees {
    {-case_id:required}
    {-role_id:required}
} {
    Find the default assignee for this role.
    
    @param case_id the ID of the case.
    @param role_id the ID of the role to assign.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set contract_name [workflow::service_contract::role_default_assignees]
    
    db_transaction {

        set object_id [workflow::case::get_element -case_id $case_id -element object_id]
    
        ns_log Notice "LARS - case::role::set_default_assignees: object_id = $object_id, [db_string foobar { select count(*) from acs_objects where object_id = :object_id }]"
    
        set impl_names [db_list select_callbacks {}]
       
        foreach impl_name $impl_names {
            # Call the service contract implementation
            set party_id_list [acs_sc::invoke \
                    -contract $contract_name \
                    -operation "GetAssignees" \
                    -impl $impl_name \
                    -call_args [list $case_id $object_id $role_id]]
    
            if { [llength $party_id_list] != 0 } {
                foreach party_id $party_id_list {
                    assignee_insert -case_id $case_id -role_id $role_id -party_id $party_id
                }
                # We stop when the first callback returned something
                break
            }
        }
    }
}

ad_proc -public workflow::case::role::assignee_insert {
    {-case_id:required}
    {-role_id:required}
    {-party_id:required}
} {
    Insert a new assignee for this role
    
    @param case_id the ID of the case.
    @param role_id the ID of the role to assign.
    @param party_id the ID of party to assign to this role

    @author Lars Pind (lars@collaboraid.biz)
} {
    if { [catch {
        db_dml insert_assignee {}
    } errMsg] } {
        set already_assigned_p [db_string already_assigned_p {}]
        if { !$already_assigned_p } {
            global errorInfo errorCode
            error $errMsg $errorInfo $errorCode
        }
    }
}

ad_proc -public workflow::case::get_activity_html {
    -case_id:required
} {
    Get the activity log for a case as an HTML chunk
} {
    #LARS TODO: Template this

    set log_html {}

    db_foreach select_log {} {
        append log_html "<b>$action_date_pretty $action_pretty_past_tense by $user_first_names $user_last_name</b>
        <blockquote>[ad_html_text_convert -from $comment_format -to "text/html" -- $comment]</blockquote>"
    }
    
    return $log_html
}



#####
#
# workflow::case::fsm
#
#####

ad_proc -public workflow::case::fsm::get_current_state {
    {-case_id:required}
} {
    Gets the current state_id of this case.

    @param case_id The case_id.
    @return The state_id of the state which this case is in

    @author Lars Pind (lars@collaboraid.biz)
} {
    return [db_string select_current_state {}]
}

ad_proc -public workflow::case::fsm::get {
    {-case_id:required}
    {-array:required}
    {-action_id {}}
} {
    Get information about an FSM case

    @param caes_id The case ID
    @param array The name of an array in which information will be returned.
    @param action_id If you supply an action here, you'll get 
    the information as it'll look after executing the given action.

    @author Lars Pind (lars@collaboraid.biz)
} {
    # Select the info into the upvar'ed Tcl Array
    upvar $array row

    if { [empty_string_p $action_id] } {
        db_1row select_case_info {} -column_array row
        set row(entry_id) {}
    } else {
        db_1row select_case_info_after_action {} -column_array row
        set row(entry_id) [db_nextval "workflow_case_log_seq"]
    }
}





#####
#
# workflow::case::action 
#
#####

ad_proc -public workflow::case::action::permission_p {
    {-case_id:required}
    {-action_id:required}
    {-user_id}
} {
    Does the user have permission to perform this action. Doesn't
    check whether the action is enabled.

    @param case_id       The ID of the case.
    @param action_id     The ID of the action
    @param user_id       The user.
    @return true or false.

    @author Lars Pind (lars@collaboraid.biz)
} {
    if { ![exists_and_not_null user_id] } {
        set user_id [ad_conn user_id]
    }

    set object_id [workflow::case::get_element -case_id $case_id -element object_id]
    set user_role_ids [workflow::case::get_user_roles -case_id $case_id -user_id $user_id]
    
    set permission_p 0

    foreach role_id $user_role_ids {

        # Is this an assigned role for this action?
        set assigned_role [workflow::action::get_assigned_role -action_id $action_id]
        if { $assigned_role == $role_id } {
            set permission_p 1
            break
        }

        # Is this an allowed role for this action?
        set allowed_roles [workflow::action::get_allowed_roles -action_id $action_id]
        if { [lsearch $allowed_roles $role_id] != -1 } {
            set permission_p 1
            break
        }
    }

    if { !$permission_p } {
        set privileges [workflow::action::get_privileges -action_id $action_id]
        foreach privilege $privileges {
            if { [permission::permission_p -object_id $object_id -privilege $privilege] } {
                set permission_p 1
                break
            }
        }
    }

    return $permission_p
}

ad_proc -public workflow::case::action::enabled_p {
    {-case_id:required}
    {-action_id:required}
} {
    Is this action currently enabled.

    @param case_id     The ID of the case.
    @param action_id     The ID of the action
    @return true or false.

    @author Lars Pind (lars@collaboraid.biz)
} {
    return [db_string select_enabled_p {} -default 0]
}

ad_proc -public workflow::case::action::available_p {
    {-case_id:required}
    {-action_id:required}
    {-user_id}
} {
    Is this action currently enabled and does the user have permission to perform it?

    @param case_id     The ID of the case.
    @param action_id     The ID of the action
    @param user_id       The user.
    @return true or false.

    @author Lars Pind (lars@collaboraid.biz)
} {
    # Always permit the no-op
    if { [empty_string_p $action_id] } {
        return 1
    }

    if { ![exists_and_not_null user_id] } {
        set user_id [ad_conn user_id]
    }
    
    if { 
        [enabled_p -case_id $case_id -action_id $action_id] 
        && 
        [permission_p -case_id $case_id -action_id $action_id -user_id $user_id] 
    } {
        return 1
    } else {
        return 0
    }
}

ad_proc -public workflow::case::action::execute {
    {-case_id:required}
    {-action_id:required}
    {-comment:required}
    {-comment_format:required}
    {-user_id}
    {-no_check:boolean}
    {-entry_id {}}
} {
    Execute the action

    @param case_id         The ID of the case.
    @param action_id       The ID of the action
    @param comment         Comment for the case activity log
    @param comment_format  Format of the comment (plain, text or html), according to 
                           OpenACS standard text formatting (HM!)
    @param user_id         User_id
    @param no_check        Use this switch to bypass a check of whether the action is
                           enabled and the user is allowed to perform it. This 
                           switch should normally not be used.
    @param entry_id        Optional entry_id for double-click protection. 
                           This can be gotten from workflow::case::fsm::get.
    @return entry_id of the new log entry.

    @author Lars Pind (lars@collaboraid.biz)
} {
    if { ![exists_and_not_null user_id] } {
        set user_id [ad_conn user_id]
    }
    
    if { !$no_check_p } {
        if { ![available_p -case_id $case_id -action_id $action_id -user_id $user_id] } {
            error "This user is not allowed to perform this action at this time."
        }
    }

    set new_state [workflow::action::fsm::get_new_state -action_id $action_id]

    db_transaction {

        # Update the workflow state
        if { ![empty_string_p $new_state] } {
            db_dml update_fsm_state {}
        }

        # Maybe get entry_id, if one wasn't supplied
        if { [empty_string_p $entry_id] } {
            set entry_id [db_nextval "workflow_case_log_seq"]
        }

        # Check if the row already exists
        set exists_p [db_string log_entry_exists_p {}]
        
        if { $exists_p } {
            return $entry_id
        }

        # We can't have empty comment_format
        if { [empty_string_p $comment_format] } {
            # We need a default value here
            set comment_format "text/plain"
        }

        # Insert activity log entry
        db_dml insert_log_entry {}

        # Assign new enabled roles, if currently unassigned
        workflow::case::assign_roles -case_id $case_id

        # Fire side-effects, both action ones and workflow ones
        # ... TODO ...

        # Notifications
        # ... TODO ...


        # LARS: TODO
        # Taken from bug-tracker
        if 0 { 
            # Setup any assignee for alerts on the bug
            if { [info exists row(assignee)] && ![empty_string_p $row(assignee)] } {
                bug_tracker::add_instant_alert \
                        -bug_id $bug_id \
                        -user_id $row(assignee)
            }
        }


    # LARS: TODO
    # Taken from bug-tracker
    if 0 { 
        set resolution {}
        if { [exists_and_not_null row(resolution)] } {
            set resolution $row(resolution)
        }
        
        # Send out notifications
        bug_tracker::bug_notify \
                -bug_id $bug_id \
                -action $action \
                -comment $description \
                -comment_format $desc_format \
                -resolution $resolution
    }
    
    }
    
    return $entry_id
}


#####
#
# workflow::case::action::fsm
#
#####

ad_proc -public workflow::case::action::fsm::new_state {
    {-case_id:required}
    {-action_id:required}
} {
    Get the new state which the workflow will be in after a certain action.

    @param case_id     The ID of the case.
    @param action_id     The ID of the action
    @return The state_id of the new state which the workflow will be in after this action

    @author Lars Pind (lars@collaboraid.biz)
} {
    set new_state [workflow::action::fsm::get_new_state -action_id $action_id]
    if { [empty_string_p $new_state] } {
        set new_state [workflow::case::fsm::get_current_state -case_id $case_id]
    }
    return $new_state
}
