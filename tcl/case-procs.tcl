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
    {-comment_mime_type:required}
    {-user_id}
} {
    Start a new case for this workflow and object.

    @param object_id The object_id which the case is about
    @param workflow_short_name The short_name of the workflow.
    @param comment_mime_type html, plain or pre
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
                -action_id [workflow::get_element -workflow_id $workflow_id -element initial_action_id] \
                -comment $comment \
                -comment_mime_type $comment_mime_type \
                -user_id $user_id \
                -initial
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
    {-all:boolean}
} {
    Find out which roles are assigned to currently enabled actions.
    If any of these currently have zero assignees, run the default 
    assignment process.
    
    @param case_id the ID of the case.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set role_id_list [list]

    if { $all_p } {
        set workflow_id [workflow::case::get_element -case_id $case_id -element workflow_id]
        set role_id_list [workflow::get_roles -workflow_id $workflow_id]
    } else {
        foreach action_id [get_enabled_actions -case_id $case_id] {
            set role_id [workflow::action::get_assigned_role -action_id $action_id]
            if { ![empty_string_p $role_id] && [lsearch $role_id_list $role_id] == -1 } {
                lappend role_id_list $role_id
            }
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

        set impl_names [workflow::role::get_callbacks \
                -role_id $role_id \
                -contract_name $contract_name]
        
        set object_id [workflow::case::get_element -case_id $case_id -element object_id]
        
        foreach impl_name $impl_names {
            # Call the service contract implementation
            set party_id_list [acs_sc::invoke \
                    -contract $contract_name \
                    -operation "GetAssignees" \
                    -impl $impl_name \
                    -call_args [list $case_id $object_id $role_id]]
    
            if { [llength $party_id_list] != 0 } {
                assignee_insert -case_id $case_id -role_id $role_id -party_ids $party_id_list

                # We stop when the first callback returned something
                break
            }
        }
    }
}

ad_proc -public workflow::case::role::get_picklist {
    {-case_id:required}
    {-role_id:required}
} {
    Get the picklist for this role.

    @param case_id the ID of the case.
    @param role_id the ID of the role.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set contract_name [workflow::service_contract::role_assignee_pick_list]

    set party_id_list [list]

    db_transaction {

        set impl_names [workflow::role::get_callbacks \
                -role_id $role_id \
                -contract_name $contract_name]

        set object_id [workflow::case::get_element -case_id $case_id -element object_id]

        foreach impl_name $impl_names {
            # Call the service contract implementation
            set party_id_list [acs_sc::invoke \
                    -contract $contract_name \
                    -operation "GetPickList" \
                    -impl $impl_name \
                    -call_args [list $case_id $object_id $role_id]]
    
            if { [llength $party_id_list] != 0 } {
                # Return after the first non-empty list
                break
            }
        }
    }

    if { [ad_conn isconnected] && [ad_conn user_id] != 0 } {
        lappend party_id_list [ad_conn user_id]
    }

    if { [llength $party_id_list] > 0 } { 
        set options [db_list_of_lists select_options {}]
    } else {
        set options {}
    }

    set options [concat { { "Unassigned" "" } } $options]
    lappend options { "Search..." ":search:"}

    return $options
}

ad_proc -public workflow::case::role::get_seach_query {
    {-case_id:required}
    {-role_id:required}
} {
    Get the search query for this role.

    @param case_id the ID of the case.
    @param role_id the ID of the role.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set contract_name [workflow::service_contract::role_assignee_subquery]

    set impl_names [workflow::role::get_callbacks \
            -role_id $role_id \
            -contract_name $contract_name]
    
    set object_id [workflow::case::get_element -case_id $case_id -element object_id]

    set subquery {}
    foreach impl_name $impl_names {
        # Call the service contract implementation
        set subquery [acs_sc::invoke \
                -contract $contract_name \
                -operation "GetSubquery" \
                -impl $impl_name \
                -call_args [list $case_id $object_id $role_id]]

        if { ![empty_string_p $subquery] } {
            # Return after the first non-empty list
            break
        }
    }
    set query "
        select distinct acs_object__name(p.party_id) || ' (' || p.email || ')' as label, p.party_id
        from   [ad_decode $subquery "" "cc_users" $subquery] p
        where  upper(coalesce(acs_object__name(p.party_id) || ' ', '')  || p.email) like upper('%'||:value||'%')
        order  by label
    "
    return $query
}

ad_proc -public workflow::case::role::get_assignee_widget {
    {-case_id:required}
    {-role_id:required}
    {-prefix "role_"}
} {
    Get the assignee widget for use with ad_form for this role.

    @param case_id the ID of the case.
    @param role_id the ID of the role.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set workflow_id [workflow::case::get_element -case_id $case_id -element workflow_id]

    workflow::role::get -role_id $role_id -array role
    set element "${prefix}$role(short_name)"
    
    set query [workflow::case::role::get_seach_query -case_id $case_id -role_id $role_id]
    set picklist [workflow::case::role::get_picklist -case_id $case_id -role_id $role_id]

    return [list "${element}:search(search)" [list label $role(pretty_name)] [list mode display] \
            [list search_query $query] [list options $picklist] optional]
}

ad_proc -public workflow::case::role::add_assignee_widgets {
    {-case_id:required}
    {-form_name:required}
    {-prefix "role_"}
} {
    Get the assignee widget for use with ad_form for this role.

    @param case_id the ID of the case.
    @param role_id the ID of the role.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set workflow_id [workflow::case::get_element -case_id $case_id -element workflow_id]
    set roles [list]
    foreach role_id [workflow::get_roles -workflow_id $workflow_id] {
        ad_form -extend -name $form_name -form [list [get_assignee_widget -case_id $case_id -role_id $role_id -prefix $prefix]]
    }
}

ad_proc -public workflow::case::role::set_assignee_values {
    {-case_id:required}
    {-form_name:required}
    {-prefix "role_"}
} {
    Get the assignee widget for use with ad_form for this role.

    @param case_id the ID of the case.
    @param role_id the ID of the role.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set workflow_id [workflow::case::get_element -case_id $case_id -element workflow_id]

    # LARS TODO:
    # Set role assignee values
    foreach role_id [workflow::get_roles -workflow_id $workflow_id] {
        workflow::role::get -role_id $role_id -array role
        set element "${prefix}$role(short_name)"

        # HACK: Only care about the first assignee
        set assignees [workflow::case::role::get_assignees -case_id $case_id -role_id $role_id]
        if { [llength $assignees] == 0 } {
            array set cur_assignee { party_id {} name {} email {} }
        } else {
            array set cur_assignee [lindex $assignees 0]
        }

        if { [uplevel info exists bug:$element] } {
            # Set normal value
            if { [uplevel template::form is_request bug] || [string equal [uplevel [list element get_property bug $element mode]] "display"] } {
                uplevel [list element set_value bug $element $cur_assignee(party_id)]
            }
            
            # Set display value
            if { [empty_string_p $cur_assignee(party_id)] } {
                set display_value "<i>None</i>"
            } else {
                set display_value [acs_community_member_link \
                        -user_id $cur_assignee(party_id) \
                        -label $cur_assignee(name)] 
                
                append display_value " (<a href=\"mailto:$cur_assignee(email)\">$cur_assignee(email)</a>)"
            }

            uplevel [list element set_properties bug $element -display_value $display_value]
        }
    }
}

ad_proc -public workflow::case::role::get_assignees {
    {-case_id:required}
    {-role_id:required}
} {
    Get the current assignees for a role in a case as a list of 
    [array get]'s of party_id, email, name.

    @param case_id the ID of the case.
    @param role_id the ID of the role.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set result {}
    db_foreach select_assignees {} -column_array row {
        lappend result [array get row]
    }
    return $result
}

ad_proc -public workflow::case::role::assignee_insert {
    {-case_id:required}
    {-role_id:required}
    {-party_ids:required}
    {-replace:boolean}
} {
    Insert a new assignee for this role
    
    @param case_id the ID of the case.
    @param role_id the ID of the role to assign.
    @param party_id the ID of party to assign to this role

    @author Lars Pind (lars@collaboraid.biz)
} {
    db_transaction { 
        if { $replace_p } {
            db_dml delete_assignees {}
        }
        
        foreach party_id $party_ids {
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
    }
}

ad_proc -public workflow::case::role::assign {
    {-case_id:required}
    {-array:required}
    {-replace:boolean}
} {
    Assign roles from an array with entries like this: array(short_name) = [list of party_ids].
    
    @param case_id The ID of the case.
    @param array Name of array with assignment info 
    @param replace Should the new assignees replace existing assignees?

    @author Lars Pind (lars@collaboraid.biz)
} {
    upvar $array assignees

    set workflow_id [workflow::case::get_element -case_id $case_id -element workflow_id]
    
    db_transaction {
        foreach name [array names assignees] {

            set role_id [workflow::role::get_id \
                    -workflow_id $workflow_id \
                    -short_name $name]
            
            assignee_insert \
                    -replace=$replace_p \
                    -case_id $case_id \
                    -role_id $role_id \
                    -party_ids $assignees($name)
        }
    }
}

ad_proc -public workflow::case::get_activity_html {
    -case_id:required
} {
    Get the activity log for a case as an HTML chunk
} {
    # LARS TODO: Template this

    set workflow_id [workflow::case::get_element -case_id $case_id -element workflow_id]
    set contract_name [workflow::service_contract::activity_log_format_title]
    
    # Get the name of any title Tcl callback proc
    set impl_names [workflow::get_callbacks \
            -workflow_id $workflow_id \
            -contract_name $contract_name]

    # If there are more than one FormatLogTitle callback, we only use the first.
    set impl_name [lindex $impl_names 0]

    set log_html {}

    db_foreach select_log {} {
        if { ![empty_string_p $impl_name] } {
            set log_title [acs_sc::invoke \
                   -contract $contract_name \
                   -operation "GetTitle" \
                   -impl $impl_name \
                   -call_args [list $entry_id]]
            set log_title [ad_decode $log_title "" "" "($log_title)"]
        }

        append log_html "<b>$creation_date_pretty $action_pretty_past_tense $log_title by $user_first_names $user_last_name</b>
        <blockquote>[ad_html_text_convert -from $comment_mime_type -to "text/html" -- $comment]</blockquote>"
    }
    
    return $log_html
}

ad_proc workflow::case::get_notification_object {
    {-type:required}
    {-workflow_id ""}
    {-case_id ""}
} {
    Get the relevant object for this notification type.

    @param type Type is one of 'workflow_assignee', 'workflow_my_cases',
    'workflow_case' (requires case_id), and 'workflow' (requires
    workflow_id).
} {
    switch $type {
        workflow_case {
            if { ![exists_and_not_null case_id] } {
                return {}
            }
            return [workflow::case::get_element -case_id $case_id -element object_id]
        }
        workflow {
            if { ![exists_and_not_null workflow_id] } {
                return {}
            }
            return [workflow::get_element -workflow_id $workflow_id -element object_id]
        }
        default {
            return [apm_package_id_from_key [workflow::package_key]]
        }
    }
}

ad_proc workflow::case::get_notification_request_url {
    {-type:required}
    {-workflow_id ""}
    {-case_id ""}
    {-return_url ""}
    {-pretty_name ""}
} {
    Get the URL to subscribe to notifications

    @param type Type is one of 'workflow_assignee', 'workflow_my_cases',
    'workflow_case' (requires case_id), and 'workflow' (requires
    workflow_id).
} {
    if { [ad_conn user_id] == 0 } {
        return {}
    }
    
    set object_id [get_notification_object \
            -type $type \
            -workflow_id $workflow_id \
            -case_id $case_id]

    if { [empty_string_p $object_id] } {
        return {}
    }

    if { ![exists_and_not_null return_url] } {
        set return_url [util_get_current_url]
    }

    set url [notification::display::subscribe_url \
            -type $type \
            -object_id  $object_id \
            -url $return_url \
            -user_id [ad_conn user_id] \
            -pretty_name $pretty_name]
    
    return $url
}

ad_proc workflow::case::get_notification_requests_multirow {
    {-multirow_name:required}
    {-label ""}
    {-workflow_id ""}
    {-case_id ""}
    {-return_url ""}
} {

} {
    array set pretty {
        workflow_assignee {my actions}
        workflow_my_cases {my cases}
        workflow_case {this case}
        workflow {cases in this workflow}
    }

    template::multirow create $multirow_name url label title
    foreach type { 
        workflow_assignee workflow_my_cases workflow_case workflow
    } {
        set url [get_notification_request_url \
                -type $type \
                -workflow_id $workflow_id \
                -case_id $case_id \
                -return_url $return_url]

        if { ![empty_string_p $url] } {
            set title "Subscribe to $pretty($type)"
            if { ![empty_string_p $label] } {
                set row_label $label
            } else {
                set row_label $title
            }
            template::multirow append $multirow_name $url $row_label $title
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
        set row(entry_id) [db_nextval "acs_object_id_seq"]
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
        set privileges [concat "admin" [workflow::action::get_privileges -action_id $action_id]]
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
    {-comment_mime_type:required}
    {-user_id}
    {-initial:boolean}
    {-entry_id {}}
} {
    Execute the action

    @param case_id            The ID of the case.
    @param action_id          The ID of the action
    @param comment            Comment for the case activity log
    @param comment_mime_type  MIME Type of the comment, according to 
                              OpenACS standard text formatting
    @param user_id            The user who's executing the action
    @param initial            Use this switch to signal that this is the initial action. This causes 
                              permissions/enabled checks to be bypasssed, and causes all roles to get assigned.
    @param entry_id           Optional item_id for double-click protection. If you call workflow::case::fsm::get
                              with a non-empty action_id, it will generate a new entry_id for you, which you can pass in here.

    @return entry_id of the new log entry (will be a cr_item).

    @author Lars Pind (lars@collaboraid.biz)
} {
    if { ![exists_and_not_null user_id] } {
        set user_id [ad_conn user_id]
    }
    
    if { !$initial_p } {
        if { ![available_p -case_id $case_id -action_id $action_id -user_id $user_id] } {
            error "This user is not allowed to perform this action at this time."
        }
    }

    set new_state_id [workflow::action::fsm::get_new_state -action_id $action_id]

    db_transaction {

        # Update the workflow state
        if { ![empty_string_p $new_state_id] } {
            db_dml update_fsm_state {}
        }

        # Double-click protection
        if { ![empty_string_p $entry_id] } {
            if {  [db_string log_entry_exists_p {}] } {
                return $entry_id
            }
        }
        
        # We can't have empty comment_mime_type
        if { [empty_string_p $comment_mime_type] } {
            # We need a default value here
            set comment_mime_type "text/plain"
        }

        # Insert activity log entry
        set extra_vars [ns_set create]
        oacs_util::vars_to_ns_set \
                -ns_set $extra_vars \
                -var_list { entry_id case_id action_id comment comment_mime_type }

        set entry_id [package_instantiate_object \
                -creation_user $user_id \
                -extra_vars $extra_vars \
                -package_name "workflow_case_log_entry" \
                "workflow_case_log_entry"]

        # Assign new enabled roles, if currently unassigned
        workflow::case::assign_roles -all=$initial_p -case_id $case_id

        # Fire side-effects
        do_side_effects \
                -case_id $case_id \
                -action_id $action_id \
                -entry_id $entry_id

        # Notifications
        notify \
                -case_id $case_id \
                -action_id $action_id \
                -entry_id $entry_id \
                -comment $comment \
                -comment_mime_type $comment_mime_type
    }
    
    return $entry_id
}

ad_proc -public workflow::case::action::do_side_effects {
    {-case_id:required}
    {-action_id:required}
    {-entry_id:required}
} {
    Fire the side-effects for this action
} {
    set contract_name [workflow::service_contract::action_side_effect]

    # Get info for the callbacks
    set workflow_id [workflow::case::get_element \
            -case_id $case_id \
            -element workflow_id]

    # Get the callbacks, workflow and action
    set impl_names [workflow::get_callbacks \
            -workflow_id $workflow_id \
            -contract_name $contract_name]
    
    set impl_names [concat $impl_names [workflow::action::get_callbacks \
            -action_id $action_id \
            -contract_name $contract_name]]

    if { [llength $impl_names] == 0 } {
        return
    }
    
    set object_id [workflow::case::get_element \
            -case_id $case_id \
            -element object_id]

    # Invoke them
    foreach impl_name $impl_names {
        acs_sc::invoke \
                -contract $contract_name \
                -operation "DoSideEffect" \
                -impl $impl_name \
                -call_args [list $case_id $object_id $action_id $entry_id]
    }   
} 
    
ad_proc -public workflow::case::action::notify {
    {-case_id:required}
    {-action_id:required}
    {-entry_id:required}
    {-comment:required}
    {-comment_mime_type:required}
} {
    Send out notifications to relevant people.
} {
    # LARS TODO:
    # Not implemented yet
    return

    # Get workflow_id
    workflow::case::get \
            -case_id $case_id \
            -array case

    workflow::get \
            -workflow_id $workflow_id \
            -array workflow

    # LARS TODO:
    # we probably need a callback to format the message...
    set subject "New notification"
    set body "Here's the body"

    # LARS TODO:
    # List of user_id's for people who are assigned to some task
    # Don't forget to map parties to users
    set assignee_list [list]

    # List of users who play some role in this case
    set case_player_list [list]

    # LARS TODO:
    # We want the subject/body to be customized depending on the type of notification

    foreach type { 
        workflow_assignee workflow_my_cases workflow_case workflow
    } {
        set subject($type) $subject
        set body($type) $body
        set force_p($type) 0
        set intersection($type) {}
    }

    set force_p(workflow_assignee) 1
    set intersection(workflow_assignee) $assignee_list
    set intersection(workflow_my_cases) $case_player_list

    
    set notified_list [list]

    foreach type { 
        workflow_assignee workflow_my_cases workflow_case workflow
    } {
        set object_id [get_notification_object \
                -type $type \
                -workflow_id $workflow_id \
                -case_id $case_id]

        if { ![empty_string_p $object_id] } {
            set notified_list [notification::new \
                    -type_id [notification::type::get_type_id -short_name $type] \
                    -object_id $object_id \
                    -response_id $case(object_id) \
                    -notif_subject $subject($type) \
                    -notif_text $body($type) \
                    -already_notified $notified_list \
                    -intersection $intersection($type) \
                    -force=$force_p($type)]
        }
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
    Get the ID of the new state which the workflow will be in after a certain action.

    @param case_id     The ID of the case.
    @param action_id     The ID of the action
    @return The state_id of the new state which the workflow will be in after this action

    @author Lars Pind (lars@collaboraid.biz)
} {
    set new_state_id [workflow::action::fsm::get_new_state -action_id $action_id]
    if { [empty_string_p $new_state_id] } {
        set new_state_id [workflow::case::fsm::get_current_state -case_id $case_id]
    }
    return $new_state_id
}
