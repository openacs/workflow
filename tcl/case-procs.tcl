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
    return [util_memoize [list workflow::case::get_user_roles_not_cached $case_id $user_id] \
                [workflow::case::cache_timeout]]
}

ad_proc -private workflow::case::get_user_roles_not_cached { case_id user_id } {
    Used internally by the workflow Tcl API only. Goes to the database
    to retrieve roles that user is assigned to.

    @author Peter Marklund
} {
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
    return [util_memoize [list workflow::case::get_enabled_actions_not_cached $case_id] \
                [workflow::case::cache_timeout]]
}

ad_proc -public workflow::case::get_enabled_actions_not_cached { case_id } {
    Used internally by the workflow API only. Goes to the databaes to
    get the enabled actions for the case.
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

    workflow::case::role::flush_cache $case_id
}

ad_proc -private workflow::case::get_activity_html { 
    {-case_id:required}
    {-action_id ""}
} {
    Get the activity log for a case as an HTML chunk.
    If action_id is non-empty, it means that we're in 
    the progress of executing that action, and the 
    corresponding line for the current action will be appended.

    @param case_id The case for which you want the activity log.
    @param action_id optional action which is currently being executed.
    @return Activity log as HTML

    @author Lars Pind (lars@collaboraid.biz)
} {
    set log_html {}

    set template {
        <b>@creation_date_pretty@ @action_pretty_past_tense@ @log_title@ by @community_member_link@</b>
        <blockquote>@comment_html@</blockquote>
    }

    # Compile and evaluate the template
    set code [template::adp_compile -string $template]

    foreach entry_arraylist [get_activity_log_info -case_id $case_id] {
        foreach { var value } $entry_arraylist {
            set $var $value
        }

        set comment_html [ad_html_text_convert -from $comment_mime_type -to "text/html" -- $comment] 
        set community_member_link [acs_community_member_link -user_id $creation_user -label "$user_first_names $user_last_name"]

        append log_html [template::adp_eval code]
    }

    if { ![empty_string_p $action_id] } {
        set pretty_past_tense [workflow::action::get_element -action_id $action_id -element pretty_past_tense]

        # sets first_names, last_name, email
        ad_get_user_info

        set now_pretty [clock format [clock seconds] -format "%m/%d/%Y"]
        # Get rid of leading zeros
        regsub {^0} $now_pretty {} now_pretty
        regsub {/0} $now_pretty {/} now_pretty
        
        append log_html "<p><b>$now_pretty $pretty_past_tense by $first_names $last_name</b></p>"
    }

    return $log_html
}

ad_proc -private workflow::case::get_activity_text { 
    {-case_id:required}
} {
    Get the activity log for a case as a text chunk

    @author Lars Pind
} {
    set log_text {}

    foreach entry_arraylist [get_activity_log_info -case_id $case_id] {
        foreach { var value } $entry_arraylist {
            set $var $value
        }

        set entry_text "$creation_date_pretty $action_pretty_past_tense $log_title by $user_first_names $user_last_name ($user_email)"

        if { ![empty_string_p $comment] } {
            append entry_text ":\n\n    [join [split [ad_html_text_convert -from $comment_mime_type -to "text/plain" -maxlen 66 -- $comment] "\n"] "\n    "]"
        }

        lappend log_text $entry_text

        
    }
    return [join $log_text "\n\n"]
}

ad_proc -private workflow::case::get_activity_log_info { 
    {-case_id:required}
} {
    Get the data for the case activity log.

    @return a list of array-lists with the following entries:    
    comment comment_mime_type creation_date_pretty action_pretty_past_tense log_title 
    user_first_names user_last_name user_email creation_user data_arraylist

    @author Lars Pind
} {
    global __cache__workflow__case__get_activity_log_info
    if { ![info exists __cache__workflow__case__get_activity_log_info] } {
        set __cache__workflow__case__get_activity_log_info [get_activity_log_info_not_cached -case_id $case_id]
    }
    return $__cache__workflow__case__get_activity_log_info
}

ad_proc -private workflow::case::get_activity_log_info_not_cached { 
    {-case_id:required}
} {
    Get the data for the case activity log. This version is cached for a single thread.

    @return a list of array-lists with the following entries:    
    comment comment_mime_type creation_date_pretty action_pretty_past_tense log_title 
    user_first_names user_last_name user_email creation_user data_arraylist

    @author Lars Pind
} {
    set workflow_id [workflow::case::get_element -case_id $case_id -element workflow_id]
    set object_id [workflow::case::get_element -case_id $case_id -element object_id]
    set contract_name [workflow::service_contract::activity_log_format_title]
    
    # Get the name of any title Tcl callback proc
    set impl_names [workflow::get_callbacks \
            -workflow_id $workflow_id \
            -contract_name $contract_name]

    # First, we build up a multirow so we have all the data in memory, which lets us peek ahead at the contents
    db_multirow -extend {comment} -local entries select_log {} { set comment $comment_string }

    
    set rowcount [template::multirow -local size entries]
    set counter 1

    set last_entry_id {}
    set data_arraylist [list]

    # Then iterate over the multirow to build up the activity log HTML
    # We need to peek ahead, because this is an outer join to get the rows in workflow_case_log_data

    set entries [list]
    template::multirow -local foreach entries {

        if { ![empty_string_p $key] } {
            lappend data_arraylist $key $value
        }

        if { $counter == $rowcount || ![string equal $last_entry_id [set "entries:[expr $counter + 1](entry_id)"]] } {
            
            set log_title_elements [list]
            foreach impl_name $impl_names {
                set result [acs_sc::invoke \
                                -contract $contract_name \
                                -operation "GetTitle" \
                                -impl $impl_name \
                                -call_args [list $case_id $object_id $action_id $entry_id $data_arraylist]]
                if { ![empty_string_p $result] } {
                    lappend log_title_elements $result
                }
            }
            set log_title [ad_decode [llength $log_title_elements] 0 "" "([join $log_title_elements ", "])"]
            
            set row [list]
            foreach var { 
                comment comment_mime_type creation_date_pretty action_pretty_past_tense log_title 
                user_first_names user_last_name user_email creation_user data_arraylist
            } {
                lappend row $var [set $var]
            }
            lappend entries $row

            set data_arraylist [list]
        }
        set last_entry_id $entry_id
        incr counter
    }

    return $entries
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
        default {
            if { ![exists_and_not_null workflow_id] } {
                return {}
            }
            return [workflow::get_element -workflow_id $workflow_id -element object_id]
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
        set return_url [ad_return_url]
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
    Returns a multirow with columns url, label, title, 
    of the possible workflow notification types. Use this to present the user with a list of 
    subscription links.
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

ad_proc workflow::case::add_log_data {
    {-entry_id:required}
    {-key:required}
    {-value:required}
} {
    Adds extra data information to a log entry, which can later
    be retrieved using workflow::case::get_log_data_by_key.
    Data are stored as simple key/value pairs.
    
    @param entry_id The ID of the log entry to which you want to attach data.
    @param key The data key.
    @param value The data value
    
    @see workflow::case::get_log_data_by_key
    @see workflow::case::get_log_data
    @author Lars Pind (lars@collaboraid.biz)
} {
    db_dml insert_log_data {}
}

ad_proc workflow::case::get_log_data_by_key {
    {-entry_id:required}
    {-key:required}
} {
    Retrieve extra data for a workflow log entry, previously stored using workflow::case::add_log_data.

    @param entry_id The ID of the log entry to which the data you want are attached.
    @param key The key of the data you're looking for.
    @return The value, or the empty string if no such key exists for this entry.

    @see workflow::case::add_log_data
    @see workflow::case::get_log_data
    @author Lars Pind (lars@collaboraid.biz)
} {
    db_string select_log_data {} -default {}
}

ad_proc workflow::case::get_log_data {
    {-entry_id:required}
} {
    Retrieve extra data for a workflow log entry, previously stored using workflow::case::add_log_data.

    @param entry_id The ID of the log entry to which the data you want are attached.
    @return A tcl list of key/value pairs in array-list format, i.e. { key1 value1 key2 value2 ... }.

    @see workflow::case::add_log_data
    @see workflow::case::get_log_data_by_key
    @author Lars Pind (lars@collaboraid.biz)
} {
    db_string select_log_data {} -default {}
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

ad_proc -public workflow::case::role::get_search_query {
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

    return [db_map select_search_results]

    
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
    
    set query [workflow::case::role::get_search_query -case_id $case_id -role_id $role_id]
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
    @return a list of 
    [array get]'s of party_id, email, name.

    @author Lars Pind (lars@collaboraid.biz)
} {
    return [util_memoize [list workflow::case::role::get_assignees_not_cached $case_id $role_id] \
                [workflow::case::cache_timeout]]
}

ad_proc -private workflow::case::role::get_assignees_not_cached { case_id role_id } {
    Proc used only internally by the workflow API. Retrieves role assignees
    directly from the database.

    @author Peter Marklund
} {
    set result {}
    db_foreach select_assignees {} -column_array row {
        lappend result [array get row]
    }
    return $result    
}

ad_proc -private workflow::case::role::flush_cache { case_id } {
    Flush all role related info for a certain case.

} {
    util_memoize_flush_regexp [list workflow::case::role::get_assignees_not_cached $case_id]    
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

    workflow::case::role::flush_cache $case_id
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
        array set row [util_memoize [list workflow::case::fsm::get_info_not_cached $case_id] \
                           [workflow::case::cache_timeout]]
        set row(entry_id) {}
    } else {
        # TODO: cache this query as well
        db_1row select_case_info_after_action {} -column_array row
        set row(entry_id) [db_nextval "acs_object_id_seq"]
    }
}

ad_proc -private workflow::case::cache_timeout {} {
    Number of seconds before we timeout the case level workflow cache.

    @author Peter Marklund
} {
    # 60 * 60 seconds is 1 hour
    return 3600
}

ad_proc -private workflow::case::fsm::get_info_not_cached { case_id } {
    Used internally by the workflow id to get FSM case info from the
    database.

    @author Peter Marklund
} {
    db_1row select_case_info {} -column_array row

    return [array get row]
}

ad_proc -private workflow::case::flush_cache { case_id } {
    Flush all cached data for the given case.

    @author Peter Marklund
} {
    # Flush scalar attributes (for fsm::get proc)
    util_memoize_flush [list workflow::case::fsm::get_info_not_cached $case_id]

    # Flush role info (assignees etc)
    workflow::case::role::flush_cache $case_id

    # Flush roles
    util_memoize_flush_regexp [list workflow::case::get_user_roles_not_cached $case_id]

    # Flush enabled actions
    util_memoize_flush [list workflow::case::get_enabled_actions_not_cached $case_id]
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

    workflow::case::flush_cache $case_id
    
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
    # Get workflow_id
    workflow::case::get \
            -case_id $case_id \
            -array case

    workflow::get \
            -workflow_id $case(workflow_id) \
            -array workflow

    set hr [string repeat "=" 70]

    array set latest_action [lindex [workflow::case::get_activity_log_info -case_id $case_id] end]
    
    set latest_action_chunk "$latest_action(action_pretty_past_tense) $latest_action(log_title) by $latest_action(user_first_names) $latest_action(user_last_name) ($latest_action(user_email))"
    
    if { ![empty_string_p $latest_action(comment)] } {
        append latest_action_chunk ":\n\n    [join [split [ad_html_text_convert -from $latest_action(comment_mime_type) -to "text/plain" -maxlen 66 -- $latest_action(comment)] "\n"] "\n    "]"
    }

    # Callback to get notification info 
    set contract_name [workflow::service_contract::notification_info]
    set impl_names [workflow::get_callbacks \
                        -workflow_id $case(workflow_id) \
                        -contract_name $contract_name]
    # We only use the first callback
    set impl_name [lindex $impl_names 0]

    if { ![empty_string_p $impl_name] } {
        set notification_info [acs_sc::invoke \
                                   -contract $contract_name \
                                   -operation "GetNotificationInfo" \
                                   -impl $impl_name \
                                   -call_args [list $case_id $case(object_id)]]

    }

    # Make sure the notification info list has at least 4 elements, so we can do below lindex's safely
    lappend notification_info {} {} {} {}
    
    set object_url [lindex $notification_info 0]
    set object_one_line [lindex $notification_info 1]
    set object_details_list [lindex $notification_info 2]
    set object_notification_tag [lindex $notification_info 3]

    if { [empty_string_p $object_one_line] } {
        # Default: Case #$case_id: acs_object__name(case.object_id)

        set object_id $case(object_id)
        db_1row select_object_name {} -column_array case_object

        set object_one_line "Case #$case_id: $case_object(name)"
    }

    # Roles and their current assignees
    foreach role_id [workflow::get_roles -workflow_id $case(workflow_id)] {
        set label [workflow::role::get_element -role_id $role_id -element pretty_name]
        foreach assignee_arraylist [workflow::case::role::get_assignees -case_id $case_id -role_id $role_id] {
            array set assignee $assignee_arraylist
            lappend object_details_list $label "$assignee(name) ($assignee(email))"
            set label {}
        }
    }

    # Find the length of the longest label
    set max_label_len 0
    foreach { label value } $object_details_list {
        if { [string length $label] > $max_label_len } {
            set max_label_len [string length $label]
        }
    }
                     
    # Output notification info
    set object_details_lines [list]
    foreach { label value } $object_details_list {
        if { ![empty_string_p $label] } {
            lappend object_details_lines "$label[string repeat " " [expr $max_label_len - [string length $label]]] : $value"
        } else {
            lappend object_details_lines "[string repeat " " $max_label_len]   $value"
        }
    }
    set object_details_chunk [join $object_details_lines "\n"]

    set activity_log_chunk [workflow::case::get_activity_text -case_id $case_id]

    set the_subject "[ad_decode $object_notification_tag "" "" "\[$object_notification_tag\] "]$object_one_line: $latest_action(action_pretty_past_tense) $latest_action(log_title) by $latest_action(user_first_names) $latest_action(user_last_name)"

    # List of user_id's for people who are in the assigned_role to any enabled actions
    set assignee_list [db_list enabled_action_assignees {}]

    # List of users who play some role in this case
    set case_player_list [db_list case_players {}]

    # Get pretty_name and pretty_plural for the case's object type
    set object_id $case(object_id)
    db_1row select_object_type_info {} -column_array object_type

    # Get name of the workflow's object
    set object_id $workflow(object_id)
    db_1row select_object_name {} -column_array workflow_object

    set next_action_chunk(workflow_assignee) "You are assigned to the next action."

    set next_action_chunk(workflow_my_cases) "You are a participant in this $object_type(pretty_name)."

    set next_action_chunk(workflow_case) "You have a watch on this $object_type(pretty_name)."

    set next_action_chunk(workflow) "You have requested to be notified about activity on all $object_type(pretty_plural) in this $workflow_object(name)."

    # Initialize stuff that depends on the notification type
    foreach type { 
        workflow_assignee workflow_my_cases workflow_case workflow
    } {
        set subject($type) $the_subject
        set body($type) "$hr
$object_one_line
$hr

$latest_action_chunk

$hr

$next_action_chunk($type)[ad_decode $object_url "" "" "\n\nPlease click here to visit this $object_type(pretty_name):\n\n$object_url"]

$hr[ad_decode $object_details_chunk "" "" "\n$object_details_chunk\n$hr"]

$activity_log_chunk

$hr
"
        set force_p($type) 0
        set subset($type) {}
    }

    set force_p(workflow_assignee) 1
    set subset(workflow_assignee) $assignee_list
    set subset(workflow_my_cases) $case_player_list
    
    set notified_list [list]

    foreach type { 
        workflow_assignee workflow_my_cases workflow_case workflow
    } {
        set object_id [workflow::case::get_notification_object \
                -type $type \
                -workflow_id $case(workflow_id) \
                -case_id $case_id]

        if { ![empty_string_p $object_id] } {

            set notified_list [concat $notified_list [notification::new \
                    -type_id [notification::type::get_type_id -short_name $type] \
                    -object_id $object_id \
                    -action_id $entry_id \
                    -response_id $case(object_id) \
                    -notif_subject $subject($type) \
                    -notif_text $body($type) \
                    -already_notified $notified_list \
                    -subset $subset($type) \
                    -return_notified]]
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
