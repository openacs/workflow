
<property name="context">{/doc/workflow {Workflow}} {Package Developer&#39;s Guide to Workflow}</property>
<property name="doc(title)">Package Developer&#39;s Guide to Workflow</property>
<master>
<h1>Package Developer&#39;s Guide to Workflow</h1>
<a href=".">Workflow Documentation</a>
 : Package Developer&#39;s
Guide
<p>By <a href="http://www.pinds.com">Lars Pind</a>
</p>
<h2>Introduction</h2>
<p>The workflow package manages a collaborative process surrounding
some object.</p>
<p>Examples of the object could be a bug in a bug tracker, a ticket
in a ticket tracker, a content item in a content management system,
a user contribution in a moderated forum/comments/whatever
application, a user&#39;s request for particpation in a
course/event/whatever.</p>
<p>For example, when a new bug is submitted, someone&#39;s assigned
to fix it, and whoever submitted it is assigned to verify the fix
and close the bug. Once the bug&#39;s fixed, the submitter will get
notified, and the bug will wait in the 'resolved' state
until the submitter has verified and then closed the bug.</p>

In order to make use of workflow in your own application, here are
the things you need to consider:
<ol>
<li>Define your default process. The idea typically is to allow
your end users to modify the process to suit their needs, but
you&#39;ll want eto provide a process which they can use as a
starting point.</li><li>Identify, declare, and implement the callbacks that your
application will need.</li><li>Write the code to set up the initial process, and to clone that
process for each package instance.</li><li>Integrate workflow support into your application&#39;s
API.</li><li>Integrate workflow support into your application&#39;s user
interface.</li><li>Integrate workflow into your application&#39;s queries</li>
</ol>
<p>Let&#39;s first look at some concepts before getting into the
technicalities of how you actually do this. For a working example
of building workflow-based applications, we recommend you take a
look at bug-tracker.</p>
<h2>Workflow Concepts</h2>
<h3>What&#39;s in a workflow</h3>
<p>In its broadest, most conceptual sense, a workflow is defined as
(and this does get a little hairy, so feel free to skip if you just
want to start developing your applicaton):</p>
<ul>
<li>A number of <strong>actions</strong> that can be executed
(open, edit, comment, resolve, edit, publish, approve, reject,
etc.) Whether or not an action is <strong>enabled</strong>, meaning
it can be executed at this point in time, will depend on the
current <strong>state</strong> of the workflow. Executing an action
may <strong>change the state</strong> of the workflow.</li><li>A definition of the possible <strong>states</strong> that the
workflow can be in. This could simply be an enumeration of states,
such as "Open", "Resolved", "Closed",
in which case we&#39;re talking about a "Finite State
Machine" (because there&#39;s a finite number of possible
states). Other models, such as petri nets, have an infinite number
of possible states. This makes things a lot more complicated, and
you don&#39;t need to bother since this first implementation of
workflow only supports finite state machines.</li><li>People participate in a workflow through their
<strong>role</strong>. For a bug tracker, the roles could be
"Submitter", "Resolver", and
"Tester". For a publication workflow, they&#39;d be
"Author", "Editor", and "Publisher".
Actions will be to roles, which in turn will be linked to users or
groups of users in a particular workflow case. The reason we link
people to actions through the concept of roles is to allow you to
specify that two or more actions should be done by the same party.
In bug-tracker, for example, the same user who opened the bug
should also close it.</li>
</ul>
<h3>Finite State Machines (FSMs)</h3>
<p>As mentioned, workflow is designed to support workflows based on
any model, however the only model currently implemented is the
finite state machine.</p>
<p>The workflow API is designed so that whenver you&#39;re using
features that are specific to finite state machines, the procedure
name will include the letters "fsm" in the name, as in
<code><a href="/api-doc/proc-view?proc=workflow::case::fsm::get">workflow::case::fsm::get</a></code>.
That way you&#39;ll know when you&#39;re hard-wiring a dependency
on the particular workflow model.</p>
<p>It&#39;s considered good practice to only use non-fsm API calls,
but in practice, it can be hard to create good user experiences
without. So feel free.</p>
<blockquote class="note">
<strong>Notation:</strong><p style="margin-left: 24px;">[Action] (State) {Role}</p><p style="margin-left: 24px;">(State1) -&gt; [Action1] -&gt;
(State2) -&gt; [Action2] -&gt; (State3)</p>
</blockquote>
<h3>Cases</h3>
<p>So much for defining the workflow. When you start
"running" your workflow, that&#39;s called a
<strong>workflow case</strong>, or simply a case. A case is
concerned with a particular object, it&#39;s always in a particular
state, and it has specific people or groups assigned to its
different roles.</p>
<h3>In-flow and out-of-flow</h3>
<p>When defining actions, we differentiate between <strong>in-flow
and out-of-flow</strong>. In-flow refers to the normal idealized
flow of the workflow, out-of-flow are the rest. Concretely what it
means is that if you&#39;re assigned to an in-flow action,
we&#39;ll bug you about it through notifications, and potentially
get mad at you if you don&#39;t come and do something to get the
workflow moving along. We don&#39;t do that with out-of-flow
actions. So we&#39;ll send a notification that says "Please
come back and resolve this bug", whereas we&#39;ll not notify
everybody who are allowed to comment saying "Please come back
and comment on this bug".</p>
<p>For bug-tracker, the normal flow (in-flow) is this:</p>
<blockquote>(Open) -&gt; [Resolve] -&gt; (Resolved) -&gt; [Close]
-&gt; (Closed)</blockquote>
<p>Other actions not in the normal flow are [Edit] and [Comment],
which are always enabled, but never change the state. And [Reopen]
which throw you back to the (Open) state. And finally [Resolved] is
in-flow when in the (Open) state, but out-of-flow when in the
(Resolved) state, meaning that you can re-resolve a bug if you need
to, but you&#39;re not required to.</p>
<p>In-flow and out-of-flow depends on the action, the state, and
the user&#39;s role in the case. For example, it might be that
users in the {Submitter} role are allowed to resolve their own
bugs, but the [Resolve] action will still only be considered
in-flow to people in the {Assignee} or {Resolver} role.</p>
<h2>The Six Steps Conceptually</h2>
<p>The recommended way a workflow is linked to an application is
this: As part of developing your application, you define your
<strong>default workflow</strong>, which will be used as a template
for customization by the users of your applications. This workflow
will be installed using the APM after-install callback, and will be
linked to your application&#39;s package-key.</p>
<p>Then when a new instance of your application is created, your
<strong>default workflow will be cloned</strong>, and the clone
linked to the new instance, so that your users can customize the
workflow for each instance of your application individually. The
default copy installed along with your package is never actually
used except for cloning when creating a new instance. This means
that your users can customize this deafult workflow, and the
modified version will serve as the boilerplate for all new package
instances.</p>
<p>In order to integrate workflow with your application, you&#39;ll
want to implement one or more of the <strong>callback service
contracts</strong>. These can do things like determine default
assignees based on certain data in your application, get
information about your application&#39;s object for use when
sending out notifications, or perform side-effects, such as
actually changing the publication state of a content item when you
execute the [Publish] action.</p>
<p>When integrating the workflow with your application&#39;s user
experience, what workflow will give you is essentially the
<strong>list of actions</strong> that the given user can perform on
the given object at the given time. In bug-tracker, for example,
bug-tracker takes care of displaying the form displaying and
editing a bug, while workflow takes care of displaying the buttons
that say [Comment], [Edit], [Resolve], [Reopen], [Close], etc.,
along the bottom of the form. Workflow also has a place to store
which form elements should be opened for editing depending on the
action being executed.</p>
<p>Your application should typically have an API for creating a new
object, editing an object, etc. This <strong>application object API
will need to be workflow-aware</strong>, so when a new object is
created, a new workflow case will be started as well. And when the
object&#39;s edited, that should generally only happen through a
workflow action, so that needs to be taken into account as
well.</p>
<p>The final step is integrating workflow into your
application&#39;s queries when you want to <strong>filter an object
listing/count based on the workflow state</strong>. This is the
only place where you&#39;ll directly be dependent on the workflow
data model.</p>
<h2>Defining Your Process (FSM)</h2>
<p>The current version of workflow only supports workflows based on
a finite state machine (FSM). Support for other models, such as
petri nets and directed graphs are possible, but not currently
designed or implemented.</p>
<p>An FSM-based workflow consists of a set of states, actions, and
roles.</p>
<p>You define a new workflow like this:</p>
<pre class="code">
set spec {
    <em>workflow-short-name</em> {
        ...
        roles {
            <em>role-short-name</em> {
               ...
            }
            ...
        }
        states {
            <em>state-short-name</em> {
               ...
            }
            ...
        }
        actions {
            <em>action-short-name</em> {
               ...
            }
            ...
        }
    }
}

set workflow_id [<a href="/api-doc/proc-view?proc=workflow::fsm::new_from_spec">workflow::fsm::new_from_spec</a> -spec $spec]
</pre>
<p>All the items (workflow, roles, states, actions) have a
short-name, which should be lowercase and use underbar (_) instead
of spaces. These are mainly used to refer to the items in other
parts of the spec.</p>
<p>The workflow short name can be used to refer to the workflow in
your application, which is useful if you have several different
workflows. The bug-tracker, for example, could have a workflow for
bugs and another one for patches.</p>
<p>Finally, you can also refer states, roles, and actions in your
application using short names, although this creates a dependency
in your application on a particular form of the workflow, and
there&#39;s currently no mechanism for ensuring that your workflow
contains the states, roles, and actions you&#39;d refer to. This is
on the todo-list.</p>
<h3>Workflow</h3>
<p>These are the attributes you can specify for the workflow
itself:</p>
<table cellspacing="1">
<tr><th colspan="2" class="header">Workflow Attributes</th></tr><tr>
<th>Attribute</th><th>Description</th>
</tr><tr bgcolor="white">
<td><code>pretty_name</code></td><td>Name used in the user interface.</td>
</tr><tr>
<td><code>package_key</code></td><td>The package that defined this workflow.</td>
</tr><tr>
<td><code>object_type</code></td><td>The parent object type which this workflow can be applied to.
If your workflow applies to any object, say 'acs_object'.
This is used in relation to callbacks when we build the user
interface for defining workflows. More on this in the section on
callbacks.</td>
</tr><tr>
<td><code>callbacks</code></td><td>Callbacks that apply to the whole workflow. If you add
side-effect callbacks, these are executed every time any action is
executed.</td>
</tr><tr>
<td><code>roles</code></td><td>Denotes the section of the spec that defines the workflow&#39;s
roles.</td>
</tr><tr>
<td><code>states</code></td><td>Denotes the section of the spec that defines the workflow&#39;s
states.</td>
</tr><tr>
<td><code>actions</code></td><td>Denotes the section of the spec that defines the workflow&#39;s
actions.</td>
</tr>
</table>
<blockquote class="note">
<strong>Internationalization
Note:</strong><p style="margin-left: 24px;">When we make workflow
internationalized for OpenACS 5.0, pretty names will contain
message keys in the form "#<em>message-key</em>#". More
about this in the package developer&#39;s guide to
internationalization.</p>
</blockquote>
<h3>Roles</h3>
<p>Attributes for roles:</p>
<table cellspacing="1">
<tr><th colspan="2" class="header">Role Attributes</th></tr><tr>
<th>Attribute</th><th>Description</th>
</tr><tr>
<td><code>pretty_name</code></td><td>Name used in the user interface.</td>
</tr><tr>
<td><code>callbacks</code></td><td>Callbacks that define how assignment of this role to users is
done.</td>
</tr>
</table>
<h3>States</h3>
<p>A few typical examples of states:</p>
<table cellspacing="1">
<tr><th colspan="2" class="header">Examples of States</th></tr><tr>
<th>Application</th><th>States</th>
</tr><tr>
<td>Ticket Tracker</td><td>(Open),(Completed), and (Closed)</td>
</tr><tr>
<td>Bug Tracker</td><td>(Open), (Triaged), (Resolved), and (Closed)</td>
</tr><tr>
<td>Content Management System Publication</td><td>(Authored), (Edited), and (Published)</td>
</tr><tr>
<td>Simple Approval</td><td>(Requested), (Approved), and (Rejected)</td>
</tr>
</table>
<p>These are the state attributes in the workflow
specification:</p>
<table cellspacing="1">
<tr><th colspan="2" class="header">State Attributes</th></tr><tr>
<th>Attribute</th><th>Description</th>
</tr><tr>
<td><code>pretty_name</code></td><td>Name used in the user interface.</td>
</tr><tr>
<td><code>hide_fields</code></td><td>A tcl list of form elements/object attributes that don&#39;t
make sense in this state. In bug-tracker, the element "Fixed
in version" doesn&#39;t make sense when the bug is (Open), and
thus not yet fixed. It&#39;s currently up to your application to do
incorporate this into your application.</td>
</tr>
</table>
<h3>Actions</h3>
<p>Actions are what the workflow allows you to do to your
object.</p>
<blockquote class="note">
<strong>Terminology:</strong><dl style="margin-left: 24px;">
<dt>Enabled</dt><dd>The action is allowed to be executed in the workflow&#39;s
current state.</dd><dt>Allowed</dt><dd>The given user is allowed to execute the action given his
current relationship to the workflow case and the object.</dd><dt>Assigned</dt><dd>The same as allowed, but the action is in-flow for this
user.</dd><dt>Available</dt><dd>The action is both enabled and allowed for this user.</dd>
</dl>
</blockquote>
<p>Some actions will <strong>always be enabled</strong>. In
bug-tracker, for example, we have [Comment] and [Edit] actions,
which are always allowed, regardless of whether the bug is (Open),
(Resolved), or (Closed).</p>
<p>Other actions, however, will only be <strong>enabled in certain
states</strong>. In bug-tracker, for example, the [Close] action is
only available in the (Resolved) state.</p>
<p>Another distinction is that <strong>some actions change the
state, and others do not</strong>. [Comment] and [Edit], for
example, do not. [Resolve], [Close], and [Reopen] do. For an FSM,
when an action changes the state, you simply specify what the new
state should be.</p>
<p>There&#39;s a special action called the <strong>initial
action</strong>. This is implicitly executed when a new case is
started for this workflow, and must always specify the
"new_state" attribute to define which state new cases
start out in.</p>
<p>Attributes for actions:</p>
<table cellspacing="1">
<tr><th colspan="2" class="header">Action Attributes</th></tr><tr>
<th>Attribute</th><th>Description</th>
</tr><tr>
<td><code>pretty_name</code></td><td>Name used in the user interface.</td>
</tr><tr>
<td><code>pretty_past_tense</code></td><td>This is used in the case log to say
"&lt;pretty_past_teense&gt; by &lt;user&gt; on
&lt;date&gt;", for example "Resolved by Jeff Davis on
April 15, 2003".</td>
</tr><tr>
<td><code>new_state</code></td><td>The short_name of the state this action puts the case into.
Leave out if the action shouldn&#39;t change the state.</td>
</tr><tr>
<td><code>initial_action_p</code></td><td>Say 't' if this is the initial action. Leave out or set
to 'f' otherwise.</td>
</tr><tr>
<td><code>allowed_roles</code></td><td>A list of roles that are allowed but not assigned to perform
this action.</td>
</tr><tr>
<td><code>assigned_role</code></td><td>A single role which is assigned to this action.</td>
</tr><tr>
<td><code>privileges</code></td><td>A list of privileges. Users who have been granted one of these
privileges on the case&#39;s object will be allowed to execute this
action.</td>
</tr><tr>
<td><code>always_enabled_p</code></td><td>Say 't' if this action should be enabled regardless of
the case&#39;s current state. Say 'f' or leave out
otherwise.</td>
</tr><tr>
<td><code>enabled_states</code></td><td>If not always enabled, enumerate the states in which this
action is enabled <em>but not</em> assigned.</td>
</tr><tr>
<td><code>assigned_states</code></td><td>Enumerate the states in which this action is enabled
<em>and</em> assigned.</td>
</tr><tr>
<td><code>edit_fields</code></td><td>A tcl list of fields which should be opened for editing when
the user is performing this action. Again, it&#39;s up to the
application to act on this.</td>
</tr><tr>
<td><code>callbacks</code></td><td>Side-effect callbacks which are executed when this action is
executed.</td>
</tr>
</table>
<h3>Putting A Workflow Together</h3>
<p>When you put this all together, here&#39;s a real live example
of what defining a workflow could look like:</p>
<pre class="code">
ad_proc -private bug_tracker::bug::workflow_create {} {
    Create the 'bug' workflow for bug-tracker
} {
    set spec {
        bug {
            pretty_name "Bug"
            package_key "bug-tracker"
            object_type "bt_bug"
            callbacks { 
                bug-tracker.FormatLogTitle 
                bug-tracker.BugNotificationInfo
            }
            roles {
                submitter {
                    pretty_name "Submitter"
                    callbacks { 
                        workflow.Role_DefaultAssignees_CreationUser
                    }
                }
                assignee {
                    pretty_name "Assignee"
                    callbacks {
                        bug-tracker.ComponentMaintainer
                        bug-tracker.ProjectMaintainer
                        workflow.Role_PickList_CurrentAssignees
                        workflow.Role_AssigneeSubquery_RegisteredUsers
                    }
                }
            }
            states {
                open {
                    pretty_name "Open"
                    hide_fields { resolution fixed_in_version }
                }
                resolved {
                    pretty_name "Resolved"
                }
                closed {
                    pretty_name "Closed"
                }
            }
            actions {
                open {
                    pretty_name "Open"
                    pretty_past_tense "Opened"
                    new_state "open"
                    initial_action_p t
                }
                comment {
                    pretty_name "Comment"
                    pretty_past_tense "Commented"
                    allowed_roles { submitter assignee }
                    privileges { read write }
                    always_enabled_p t
                }
                edit {
                    pretty_name "Edit"
                    pretty_past_tense "Edited"
                    allowed_roles { submitter assignee }
                    privileges { write }
                    always_enabled_p t
                    edit_fields { 
                        component_id 
                        summary 
                        found_in_version
                        role_assignee
                        fix_for_version
                        resolution 
                        fixed_in_version 
                    }
                }
                reassign {
                    pretty_name "Reassign"
                    pretty_past_tense "Reassigned"
                    allowed_role { submitter assignee }
                    privileges { write }
                    enabled_states { resolved }
                    assigned_states { open }
                    edit_fields { role_assignee }
                }
                resolve {
                    pretty_name "Resolve"
                    pretty_past_tense "Resolved"
                    assigned_role "assignee"
                    enabled_states { resolved }
                    assigned_states { open }
                    new_state "resolved"
                    privileges { write }
                    edit_fields { resolution fixed_in_version }
                    callbacks { bug-tracker.CaptureResolutionCode }
                }
                close {
                    pretty_name "Close"
                    pretty_past_tense "Closed"
                    assigned_role "submitter"
                    assigned_states { resolved }
                    new_state "closed"
                    privileges { write }
                }
                reopen {
                    pretty_name "Reopen"
                    pretty_past_tense "Reopened"
                    allowed_roles { submitter }
                    enabled_states { resolved closed }
                    new_state "open"
                    privileges { write }
                }
            }
        }
    }

    set workflow_id [<a href="/api-doc/proc-view?proc=workflow::fsm::new_from_spec">workflow::fsm::new_from_spec</a> -spec $spec]
    
    return $workflow_id
}
</pre>
<h2>Defining Callbacks</h2>
<p>There are a number of different types of callbacks, each of
which applies to different workflow items (workflows, roles,
states, actions). They&#39;re all defined as service contracts.</p>
<p>In order to make use of them, your application will need to
implement these service contracts, and register the implementation
with the relevant workflow item through the 'callbacks'
attribute in the spec above.</p>
<p>Here are the types of callbacks defined, how they&#39;re used,
and the workflow items they apply to.</p>
<table cellspacing="1">
<tr><th colspan="3" class="header">Service contracts</th></tr><tr>
<th>Service Contract</th><th>Applies To</th><th>Description</th>
</tr><tr>
<td><code>Workflow.Role_DefaultAssignees</code></td><td>Roles</td><td>Used to get the default assignees for a role. Called for all
roles when a case is started. Also called for roles with no
assignees, when that role is assigned to an action. Should return a
list of party_id&#39;s.</td>
</tr><tr>
<td><code>Workflow.Role_AssigneePickList</code></td><td>Roles</td><td>Used when the users wants to reassign a role to populate a
drop-down list of the most likely users/groups to assign this role
to. Should return less than 25 users/groups. Should return a list
of party_id&#39;s.</td>
</tr><tr>
<td><code>Workflow.Role_AssigneeSubQuery</code></td><td>Roles</td><td>A subquery used to limit the scope of the user&#39;s search for
a new assignee for a role. Could typically be used to limit the
search to members of a particular group, organizers of a particular
event, etc.
<p>Should return a subquery ready to be included in the from-clause
of a query, which will be used when querying for users, for example
'(select * from parties where ...)', (sub-selects must be
in parenthesis), or simply 'cc_users' or 'parties'.
Defaults to 'cc_users'.</p>
</td>
</tr><tr>
<td><code>Workflow.Action_SideEffect</code></td><td>Workflows, Actions</td><td>This is executed whenever the given action is executed. If
specified for the workflow, it will be executed whenever any action
is executed on the workflow. For details about how to use this in
conjunction with log entry data and format log title, see below.
<p>Side-effects are executed after the application object has been
updated, after the workflow state has been changed, after the log
entry has been crated, and roles assigned, but before notifications
have been sent out.</p>
</td>
</tr><tr>
<td><code>Workflow.ActivityLog_FormatTitle</code></td><td>Workflows</td><td>Used to format the title of the case log. In bug-tracker, this
is used to get the resolution code displayed in the case log as
"Resolved (Fixed)" or "Resolved (Not
Reproducable)".
<p>The implementation should return the text string that should go
into the parenthesis. The parenthesis are automatically added if
the returned string is non-empty.</p>
</td>
</tr><tr>
<td><code>Workflow.NotificationInfo</code></td><td>Workflows</td><td>Allows the application to supply information about the case
object for the notification.
<p>Should return the notification information as a 4-element list
containing:</p><ol>
<li>url</li><li>one-line summary</li><li>details about the object in the form of an array-list with
label/value</li><li>tag for the notification subject (optional). If present, it
will be put inside brackets [].</li>
</ol>
</td>
</tr>
</table>
<p>All the service contracts have 3 operations each. The first two
are the same for all service contracts, and they really just act
like static variables:</p>
<table cellspacing="1">
<tr><th colspan="4" class="header">Common service contract
operations</th></tr><tr>
<th>Operation</th><th>Input</th><th>Output</th><th>Description</th>
</tr><tr>
<td>GetObjectType</td><td><em>None</em></td><td>object_type:string</td><td>Get the object type for which this implementation is valid. If
your implementation is valid for any object, return
'acs_object', otherwise return the object type.</td>
</tr><tr>
<td>GetPrettyName</td><td><em>None</em></td><td>pretty_name:string</td><td>Get the pretty name of this implementation. This will be used
in the user interface to let the workflow designer pick which
implementation to use.</td>
</tr>
</table>
<p>The third operation is the one that does the real work. Here are
the inputs and outputs:</p>
<table cellspacing="1">
<tr><th colspan="4" class="header">Specific service contract
operations</th></tr><tr>
<th>Contract</th><th>Operation</th><th>Input</th><th>Output</th>
</tr><tr>
<td>Workflow.Role_DefaultAssignees</td><td>GetAssignees</td><td>case_id:integer<br>
object_id:integer<br>
role_id:integer</td><td>party_ids:integer,multiple</td>
</tr><tr>
<td>Workflow.Role_AssigneePickList</td><td>GetPickList</td><td>case_id:integer<br>
object_id:integer<br>
role_id:integer</td><td>party_ids:integer,multiple</td>
</tr><tr>
<td>Workflow.Role_AssigneeSubQuery</td><td>GetSubquery</td><td>case_id:integer<br>
object_id:integer<br>
role_id:integer</td><td>subquery:string</td>
</tr><tr>
<td>Workflow.Action_SideEffect</td><td>DoSideEffect</td><td>case_id:integer object_id:integer action_id:integer
entry_id:integer</td><td><em>None</em></td>
</tr><tr>
<td>Workflow.ActivityLog_FormatTitle</td><td>GetTitle</td><td>case_id:integer object_id:integer action_id:integer
entry_id:integer data_arraylist:string,multiple</td><td>title:string</td>
</tr><tr>
<td>Workflow.NotificationInfo</td><td>GetNotificationInfo</td><td>case_id:integer object_id:integer</td><td>info:string,multiple</td>
</tr>
</table>
<p>For the most up-to-date information about the service contracts,
your safest bet is to refer to the user-visible pages of the
acs-service-contract package itself, which will let you view your
currently installed contracts and implementations.</p>
<h3>Log Entry Data and Log Entry Titles</h3>
<p>One noteworthy thing that side-effects can be used for, is to
record information about a log entry for use later in displaying a
more detailed log entry title, or can be used to e.g. tie a
workflow log entry to a particular content repository revision,
etc.</p>
<p>Using <a href="/api-doc/proc-view?proc=workflow::case::add_log_data">workflow::case::add_log_data</a>,
you can add arbitrary key/value pairs to a log entry. These can the
be retrieved later using <a href="/api-doc/proc-view?proc=workflow::case::get_log_data_by_key">workflow::case::get_log_data_by_key</a>,
and <a href="/api-doc/proc-view?proc=workflow::case::get_log_data">workflow::case::get_log_data</a>.</p>
<h2>Installing and Instantiating (APM Tcl Callbacks)</h2>
<p>Here are the workflow-related operations that you&#39;ll
typically want your application to do from the APM Tcl
Callbacks:</p>
<dl>
<dt>after-install</dt><dd><ul>
<li>Register service contract implementations</li><li>Create default workflow (<code><a href="/api-doc/proc-view?proc=workflow::fsm::new_from_spec">workflow::fsm::new_from_spec</a></code>)</li>
</ul></dd><dt>before-uninstall</dt><dd><ul>
<li>Delete default workflow (<code><a href="/api-doc/proc-view?proc=workflow::delete">workflow::delete</a></code>)</li><li>Unregister service contract implementations</li>
</ul></dd><dt>before-upgrade</dt><dd><ul>
<li>Add new service contract implementations</li><li>Add new workflows</li><li>Make changes to existing default workflows (if the installed
verison is not modified) (this isn&#39;t yet supported on the
workflow API)</li>
</ul></dd><dt>after-instantiate</dt><dd><ul><li>Clone default workflow to create a new workflow attached to the
instance (<code><a href="/api-doc/proc-view?proc=workflow::fsm::clone">workflow::fsm::clone</a></code>)</li></ul></dd><dt>before-uninstantiate</dt><dd><ul><li>Delete the workflow attached to the instance (<code><a href="/api-doc/proc-view?proc=workflow::delete">workflow::delete</a></code>)</li></ul></dd>
</dl>
<p>To see what this could look like in practice, check out
<code>packages/bug-tracker/tcl/install-procs.tcl</code>.</p>
<h2>Integrating With Your Application&#39;s API</h2>
<p>Newer applications will define a namespace for each of the
objects it defines, which will contain procs like "get",
"new", "delete", etc., to manipulate these
objects.</p>
<p>Given such a setup, here are the procs that you want to
integrate workflow into for your workflow-integrated objects. For a
real-life example, see
<code>packages/bug-tracker/tcl/bug-procs.tcl</code> and search for
"workflow::".</p>
<dl>
<dt>get</dt><dd>In addition to your application&#39;s object data, you&#39;ll
want to call <code><a href="/api-doc/proc-view?proc=workflow::case::get_id">workflow::case::get_id</a></code>
to get the case_id for your object, and then either <code><a href="/api-doc/proc-view?proc=workflow::case::get">workflow::case::get</a></code>
or <code><a href="/api-doc/proc-view?proc=workflow::case::fsm::get">workflow::case::fsm::get</a></code>
in order to get state information from workflow to include in the
data set returned by your API proc.</dd><dt>new</dt><dd>When creating a new object, you should also start a new
workflow case for that object using <code><a href="/api-doc/proc-view?proc=workflow::case::new">workflow::case::new</a></code>.</dd><dt>edit</dt><dd>Editing an object should only happen through a workflow action,
if you want to have a complete audit log (workflow case log). Thus,
your edit proc should take the following arguments, in addition to
the object_id and the array containing the object data:
<pre>
      -action_id:required
      -comment:required
      -comment_format:required
      {-entry_id {}}
    
</pre>
(entry_id is for double-click protection).
<p>First, you should update your application object data as normal.
Then you&#39;ll probably want to use <code><a href="/api-doc/proc-view?proc=workflow::case::get_id">workflow::case::get_id</a></code>
to find the case_id. If you have assignment integrated in your
form, you&#39;ll want to call <code><a href="/api-doc/proc-view?proc=workflow::case::role::assign">workflow::case::role::assign</a></code>
to pass these on to workflow, and finally you&#39;ll say
<code><a href="/api-doc/proc-view?proc=workflow::case::action::execute">workflow::case::action::execute</a></code>
to execute the action, including state changes, side-effects, and
notifications.</p>
</dd>
</dl>
<h2>Integrating With Your Application&#39;s User Interface</h2>
<p>Usually, you&#39;ll want one page that lists all the objects in
your package instance, and another that lets the user view/edit one
object, called the object form page. This section is about the
object form page, the next section is about the object listing
page.</p>
<p>For a real-life example, look at
<code>packages/bug-tracker/www/bug.tcl</code>. You may want to have
that handy while reading through this.</p>
<p>We&#39;re hoping to make some streamlining of both ad_form and
workflow to make this form page integration even easier at some
point. But no promises.</p>
<p>Use <code><a href="/api-doc/proc-view?proc=workflow::case::get_id">workflow::case::get_id</a></code>
to get the case_id.</p>
<p>If you want buttons along the bottom of the form like
bug-tracker, use the new 'action' feature of the form
builder. What you do is pass a list of possible actions to the form
builder as a list-of-lists with { label value }. These will be
displayed as buttons at the bottom of the form.</p>
<p>When one of these buttons are clicked, the form will be in
edit-mode, and you can use <code>form get_action</code> to get the
value of the action chosen.</p>
<p>So up top, you&#39;ll want to ask the form if an action is in
progress, and which one it is, by saying <code>set action_id [form
get_action <em>form-id</em>]</code>. If no action is in progress
this will return the empty string.</p>
<p>Then you should check that this action is currently available to
this user by saying <code><a href="/api-doc/proc-view?proc=workflow::case::action::available_p">workflow::case::action::available_p</a></code>.</p>
<p>To get the currently available actions so you can offer them to
the user, use <code><a href="/api-doc/proc-view?proc=workflow::case::get_available_actions">workflow::case::get_available_actions</a></code>
which will return the action_id&#39;s, then <code><a href="/api-doc/proc-view?proc=workflow::action::get">workflow::action::get</a></code>
to get the details about each of the actions.</p>
<p>If you&#39;re using <code>ad_form</code>, and you want only one
assignee per role, and you want assignment integrated with your
form, use <code><a href="/api-doc/proc-view?proc=workflow::case::role::add_assignee_widgets">
workflow::case::role::add_assignee_widgets</a></code> to add the
widgets. It&#39;ll do an <code>ad_form -extend</code>, so
they&#39;ll appear at the point at which you call this proc.</p>
<p>To set the editable fields as defined for the action, do
this:</p>
<pre>
if { ![empty_string_p $action_id] } {
    foreach field [<a href="/api-doc/proc-view?proc=workflow::action::get_element">workflow::action::get_element</a> -action_id $action_id -element edit_fields] { 
        element set_properties bug $field -mode edit 
    }
}
</pre>
<p>Similarly, on submit, you&#39;ll want to set the value of the
editable fields.</p>
<p>To populate values of the assignee widgets, use <code><a href="/api-doc/proc-view?proc=workflow::case::role::set_assignee_values">
workflow::case::role::set_assignee_values</a></code> in your
<code>on_request</code> block.</p>
<p>To add the case log to the comment field, use <code><a href="/api-doc/proc-view?proc=workflow::case::get_activity_html">workflow::case::get_activity_html</a></code>
and feed it to the <code>before_html</code> property of a
textarea.</p>
<h2>Integrating With Your Application&#39;s Queries</h2>
<p>Here&#39;s an example of how the bug-tracker integrates with
workflow for nformation about the current state of bugs.</p>
<blockquote><pre>
select b.bug_id,
       ...

       st.pretty_name as pretty_state,
       st.short_name as state_short_name,
       st.state_id,
       st.hide_fields,

       assignee.party_id as assignee_party_id,
       assignee.email as assignee_email,
       assignee.name as assignee_name

from   bt_bugs b,
       workflow_cases cas left outer join
       (select rpm.case_id,
               p.party_id,
               p.email,
               acs_object__name(p.party_id) as name
          from workflow_case_role_party_map rpm,
               parties p
         where rpm.role_id = :action_role
           and p.party_id = rpm.party_id
         ) assignee on (cas.case_id = assignee.case_id),
       workflow_case_fsm cfsm,
       workflow_fsm_states st 
where  cas.workflow_id = :workflow_id
and    cas.object_id = b.bug_id
and    cfsm.case_id = cas.case_id
and    st.state_id = cfsm.current_state
and    b.project_id = :package_id
order  by $order_by_clause
</pre></blockquote>
<p>Note the outer join to get the assignee(s). The joins to get
information about the current state is straight-forward.</p>
<h2>Good Luck!</h2>
<p>That&#39;s all I think you&#39;ll need to know to start
developing workflow-enabled applications.</p>
<p>Let me know how it goes, or of something&#39;s missing, by
posting on the <a href="http://openacs.org/forums/">OpenACS
Forums</a>.</p>
<hr>
<a href="mailto:lars\@pinds.com"></a>
<address>lars\@pinds.com</address>
