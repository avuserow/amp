[%# USE date %]
<table>
[% FOREACH entry IN playlist %]
    <tr>
        <td>[% entry.artist %] - [% entry.title %] ([% entry.length %])</td>
    </tr>
[% END %]
</table>
