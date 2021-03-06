// ================== helpers for sidebar ============================
function time_tracker_action(url) {
    $.ajax({url:url,
        type:'POST',
        dataType:'html', 
        success:function (transport) {
          $('#time_tracker_sidebar_links').html(transport);
        },
    });
}

// ================== helpers for date-filter chooser ============================
// this function is unused till the date-shifter will be ported to jquery too

function get_time_span(time, obj) {
    // default action is getting the actual month
    var action = "get_this_time_span";
    if (time == "next") {
        action = "get_next_time_span";
    } else if (time == "prev") {
        action = "get_prev_time_span";
    }

    var date1 = $('#values_tt_start_date_1').val();
    var date2 = $('#values_tt_start_date_2').val();

    $.ajax({url:'tt_date_shifter/' + action + '?date1=' + date1 + '&date2=' + date2,
        type:'GET',
        success:function (transport) {

            var ds = transport;

            $('#values_tt_start_date_1').val(ds.start_date);
            $('#values_tt_start_date_2').val(ds.stop_date);
        }
    });

}

// ================== booking_form helpers ============================

function updateBookingHours(name) {
    var start_field = $("#" + name + "_start_time");
    var stop_field = $("#" + name + "_stop_time");
    var spent_field = $("#" + name + "_spent_time");

    var start = start_field.val();
    var stop = stop_field.val();
    // if the stop-time looks smaller than the start-time, we assume a booking over midnight
    if (timeString2sec(stop) < timeString2sec(start)) {
        var temp = calcBookingHelper(start, "24:00", 1);
        spent_field.val(calcBookingHelper(stop, temp, 2));
    } else {
        spent_field.val(calcBookingHelper(start, stop, 1));
    }
}

function updateBookingStop(name) {
    var start_field = $("#" + name + "_start_time");
    var stop_field = $("#" + name + "_stop_time");
    var spent_field = $("#" + name + "_spent_time");

    stop_field.val(calcBookingHelper(start_field.val(), spent_field.val(), 2));
}

function updateBookingProject(name) {
    var issue_id_field = $("#" + name + "_issue_id");
    var project_id_field = $("#" + name + "_project_id");
    var project_id_select = $("#" + name + "_project_id_select");

    var issue_id = issue_id_field.val();
    // check if the string is blank
    if (!issue_id || $.trim(issue_id) === "") {
        project_id_select.attr('disabled', false);
        issue_id_field.removeClass('invalid');
        project_id_field.val(project_id_select.val());
    } else {
        $.ajax({url:'/time_bookings/get_issue/' + issue_id,
            type:'GET',
            success:function (transport) {
                issue_id_field.removeClass('invalid');
                var issue = transport.issue;
                if (issue == null) {
                    project_id_select.attr('disabled', false);
                    project_id_field.val(project_id_select.val());
                } else {
                    project_id_select.attr('disabled', true);
                    project_id_field.val(issue.project_id);
                    $("#" + project_id_select.attr("id")).val(issue.project_id);
                }
            },
            error:function () {
                project_id_select.attr('disabled', false);
                issue_id_field.addClass('invalid');
                project_id_field.val(project_id_select.val());
            }
        });
    }
}

function timeString2sec(str) {
    if (str.match(/\d\d?:\d\d?:\d\d?/)) {     //parse general input form hh:mm:ss
        var arr = str.trim().split(':');
        return new Number(arr[0]) * 3600 + new Number(arr[1]) * 60 + new Number(arr[2]);
    }
    if (str.match(/\d\d?:\d\d?/)) {     //parse general input form hh:mm:ss
        var arr = str.trim().split(':');
        return new Number(arr[0]) * 3600 + new Number(arr[1]) * 60;
    }
    // more flexible parsing for inputs like:  12d 23sec 5min
    var time_factor = {"s":1, "sec":1, "m":60, "min":60, "h":3600, "d":86400};
    var sec = 0;
    var time_arr = str.match(/\d+\s*\D+/g);
    jQuery.each(time_arr, function (index, item) {
        item = item.trim();
        var num = item.match(/\d+/);
        var fac = item.match(/\D+/)[0].trim().toLowerCase();
        if (time_factor[fac]) {
            sec += num * time_factor[fac];
        }
    });
    return sec;
}

function calcBookingHelper(ele1, ele2, calc) {
    var sec1 = timeString2sec(ele1);
    var sec2 = timeString2sec(ele2);
    if (calc == 1) {
        var val = sec2 - sec1;
    }
    if (calc == 2) {
        val = sec1 + sec2;
    }
    var h = Math.floor(val / 3600);
    var m = Math.floor((val - h * 3600) / 60);
    var s = Math.floor(val - (h * 3600 + m * 60));
    h < 10 ? h = "0" + h.toString() : h = h.toString();
    m < 10 ? m = "0" + m.toString() : m = m.toString();
    s < 10 ? s = "0" + s.toString() : s = s.toString();
    while (calc == 2 && h > 23) h = h - 24;    //stop_time should be between 0-24 o clock
    return h + ":" + m + ":" + s;
}
