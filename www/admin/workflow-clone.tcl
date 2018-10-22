ad_page_contract {

    Workflow Edit page

    @author        Jeff Wang (jeff@ctrl.ucla.edu)
    @creation-date 3/17/2005

    @cvs-id  $Id$
} {
    {return_url [get_referrer]}
}


set title "Workflow Clone"

set context [list "Workflow Clone"]
set default_workflows [db_list_of_lists get_wfs {}]


workflow::tree::sorter::create -multirow "package_options" -sort_by sort_key

db_multirow -extend {sort_key} package_options get_packages  {} {
    set sort_key [workflow::tree::sorter::make_full_key_for \
		      -multirow "package_options" \
		      -partial_key $rawname \
		      -id  $object_id \
		      -level $level]
}

workflow::tree::sorter::sort -multirow "package_options"
set unprocessed_list [template::util::multirow_to_list  "package_options"]

# Replace leading spaces with '&nbsp;'
foreach item $unprocessed_list {
    set name	[lindex $item 7]
    set new_lines	""

    for {set i 0} {$i < [string length $name]} {incr i} {
	if {[string index $name $i] eq " "} {
	    append new_lines "&nbsp;"
	} else {
	    break;
	}
    }

    set name "$new_lines $name"

    set value [lindex $item 11]
    lappend package_options [list $name $value]
}


ad_form -name "clone" -form {
    {wf:text(select) {label {Select a workflow to clone:}} {options $default_workflows} }
    {short_name:text(text) {label {Short Name:}}}
    {pretty_name:text(text) {label {Pretty Name:}}}
    {package:text(select) {label {Select the package:}} {options $package_options}}
}  -on_submit {
    set update_array(short_name) $short_name
    set update_array(pretty_name) $pretty_name

    workflow::fsm::clone \
	    -workflow_id $wf \
	    -object_id $package \
	    -array "update_array"

} -after_submit {
    ad_returnredirect -allow_complete_url $return_url
} -export {return_url}
