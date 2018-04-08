ad_library {
    Procedures in the workflow::graph namespace.
 
     @creation-date 5 April 2005
     @author jmhek@cs.ucla.edu
     @cvs-id $Id$
}
 
namespace eval workflow::graph {}
 
ad_proc -public workflow::graph::draw {
    {-workflow_id:required}
    {-filename ""}
    {-highlight ""}
    {-options_array_name ""}
} {
         This procedure is used to generate .dot file of graphviz
         @param workflow_id
         @param filename
         @param highlight A list of states to highlight, the first element in the list is the current state, all other elements are previous states.
         @param options_array_name the string name of the hash of additional options. Keys are:
            include_subject_count: If this option has a value of 1, then include the subject count by state.
            subject_term_pl : the plural pretty name of the subject type (rats, tissues, subjects, etc)
            subject_term    : singular pretty name of the subject type (rat, tissue, subject, etc)
         @return 0 if success, o.w. 1
} {
         # set filename
    set path [acs_package_root_dir workflow]
    append path /www/admin/graph
     
    if {$options_array_name ne ""} {
	upvar $options_array_name options
    }
     
    #check to see what options were passed in, init things that aren't there
    set available_options [list "include_subject_count" "subject_term" "subject_term_pl"]
    set option_names    [array names options]
     
    foreach opt $available_options {
	
	#default the value
	if {$opt ni $option_names} {
	    set options($opt) ""
	}
    }
     
     
         #exchange some defaults for more descriptive values
    if {$options(subject_term) eq ""} {
	set options(subject_term) "subject"
	set options(subject_term_pl) "subjects"
    }
     
     
    if {$filename eq ""} {
	set filename workflow_$workflow_id
    }
     
    set current_state ""
    set previous_state ""
    if {$highlight ne ""} {
	set current_state [lindex $highlight 0]
	set previous_state [lreplace $highlight 0 0]
    }
     
    set dot "digraph workflow_$workflow_id \{\n"
    #append dot "  graph \[size=\"16,16\"\];\n"
    append dot "  node \[fontname=\"Courier\", color=lightblue2, style=filled\];\n"
    append dot "  edge \[fontname=\"Courier\"\];\n"
     
    set states [workflow::fsm::get_states -workflow_id $workflow_id]
     
    #get the subject counts for the workflow
    if {$options(include_subject_count) == 1} {
	ptracker::subject::get_subject_count_in_workflow -workflow_id $workflow_id\
	    -array_name "subjects_in_workflow"
    }
     
    foreach state_id $states {
	workflow::state::fsm::get -state_id $state_id -array "state_info"
	 
	set num_subjects_in_state ""
	if {[array exists subjects_in_workflow]} {
	    set subject_count 0
	    if {$state_id in [array names subjects_in_workflow]} {
		set subject_count $subjects_in_workflow($state_id)
	    }
	     
	    set descriptor $options(subject_term_pl)
	    if {$subject_count == 1} {
		set descriptor $options(subject_term)
	    }
	    set num_subjects_in_state "($subject_count $descriptor)"
	}
	 
	if {$state_id == $current_state} {
	    append dot "  state_$state_id \[label=\"$state_info(pretty_name) $num_subjects_in_state\", color=darkorange1\];\n"
	} elseif {$state_id in $previous_state} {
	    append dot "  state_$state_id \[label=\"$state_info(pretty_name) $num_subjects_in_state\", color=steelblue3\];\n"
	} else {
	    append dot "  state_$state_id \[label=\"$state_info(pretty_name) $num_subjects_in_state\"\];\n"
	}
    }
     
    set actions [workflow::action::fsm::get_ids -workflow_id $workflow_id]
    foreach action_id $actions {
	workflow::action::get -action_id $action_id -array "action_info"
	 
	if {$action_info(new_state) ne ""} {
	    if {$action_info(assigned_states) ne ""} {
		foreach x $action_info(assigned_state_ids) {
		    append dot "  state_$x -> state_$action_info(new_state_id) \[label=\"$action_info(pretty_name)\"\];\n"
		}
	    }
	     
	    if {$action_info(enabled_states) ne ""} {
		foreach x $action_info(enabled_state_ids) {
		    append dot "  state_$x -> state_$action_info(new_state_id) \[label=\"$action_info(pretty_name)\"\];\n"
		}
	    }
	}
    }
    append dot "\}\n"
     
    set flag [catch {
	template::util::write_file $path/$filename\.dot $dot
	exec /usr/bin/dot -Tjpg $path/$filename\.dot -o $path/$filename\.jpg
    } errmsg]
     
    return $flag
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
