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
        # Insert the case
        set case_id [insert -workflow_id $workflow_id -object_id $object_id]

        # Execute the initial action
        workflow::case::action::execute \
                -case_id $case_id \
                -action_id [workflow::action::get_initial_action -workflow_id $workflow_id] \
                -comment $comment \
                -comment_format $comment_format \
                -user_id $user_id \
                -no_check
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
        return {}
    }
}

ad_proc -public workflow::case::get_object_id {
    {-case_id:required}
} {
    Gets the object_id from the case.

    @param case_id The case_id.
    @return The object_id of the case.

    @author Lars Pind (lars@collaboraid.biz)
} {
    return [db_string select_object_id {}]
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
    @return            A list of id:s of the actions which are currently 
                       enabled
                       
    @author Lars Pind (lars@collaboraid.biz)
} {
    set action_list [list]
    db_foreach select_enabled_actions {} {
        lappend action_list $action_id
    }

    return $action_list
}

ad_proc -public workflow::case::get_user_actions {
    {-case_id:required}
    -user_id
} {
    Get the currently enabled actions, which the user has permission
    to execute.

    @param case_id     The ID of the case.
    @return            A list of id:s of the actions 
                       which are currently enabled

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
        if { [lsearch $role_id_list $role_id] == -1 } {
            lappend role_id_list $role_id
        }
    }

    foreach role_id $role_id_list {
        set num_assignees [db_string select_num_assignees {}]

        if { $num_assignees == 0 } {
            workflow::case::role::set_default_assignees -case_id $case_id -role_id $role_id
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
    set contract_name [workflow::service_contract::role_default_assignee]
    
    set object_id [workflow::case::get_object_id -case_id $case_id]

    db_foreach select_assignment_rules {} {
        
        # Run the service contract
        set party_id_list [acs_sc_call $contract_name "GetAssignees" [list $case_id $object_id $role_id] $impl_name]
        
        if { [llength $party_id_list] != 0 } {
            foreach party_id $party_id_list {
                assignee_insert -case_id $case_id -role_id $role_id -party_id $party_id
            }
            # We stop when the first callback returned something
            break
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

    set object_id [workflow::case::get_object_id -case_id $case_id]
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

        # Insert activity log entry
        set entry_id [db_nextval "workflow_case_log_seq"]
        db_dml insert_log_entry {}
        
        # Assign new enabled roles, if currently unassigned
        workflow::case::assign_roles -case_id $case_id

        # Fire side-effects, both action ones and workflow ones
        # ... TODO ...

        # Notifications
        # ... TODO ...
    }
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
