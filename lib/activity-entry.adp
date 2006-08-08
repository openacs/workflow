<p style="font-weight: bold;">
  #workflow.lt_creation_date_pretty_# 
  <if @community_member_url@ not nil><a href="@community_member_url@">@user_first_names@ @user_last_name@</a></if>
  <else>@user_first_names@ @user_last_name@</else>
</p>
<if @comment_html@ not nil><blockquote style="max-width: 700px;">@comment_html;noquote@</blockquote></if>

