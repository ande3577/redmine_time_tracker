/*
 * This script updates the element 'id' with 'newContent' if the two contents differ
 */
function updateElementIfChanged(id, newContent) {
    el = $(id);
    if (el.innerHTML != newContent) {
        el.update(newContent);
    }
}

// ================== time_tracker_controller helpers ============================

function updateTTControllerForm(obj) {
    if (obj.nodeName == "FORM") {
        var form = obj;
        new Ajax.Request('time_trackers/update.json?' + Form.serializeElements(form.getInputs()),
            {
                method:'put',
                onSuccess:function (transport) {
                    var tt = transport.responseJSON.time_tracker;
                    form.time_tracker_issue_id.value = tt.issue_id;
                    (tt.issue_id == null) ? form.project_id_select.enable() : form.project_id_select.disable();
                    form.time_tracker_comments.value = tt.comments;
                    form.time_tracker_project_id.value = tt.project_id;
                    select_options = form.project_id_select;
                    for (i = 0; i < select_options.length; i++) {
                        if (select_options[i].value == tt.project_id) select_options[i].selected = true;
                    }
                    dat = new Date(Date.parse(tt.started_on));
                    //form.time_tracker_start_time.value = dat.getHours().toString()+':'+dat.getMinutes().toString();
                    form.time_tracker_start_time.value = dat.toLocaleTimeString();
                    year = dat.getFullYear().toString();
                    month = dat.getMonth() + 1;
                    (month < 10) ? month = '0' + month.toString() : month = month.toString();
                    day = dat.getDate();
                    (day < 10) ? day = '0' + dat.getDate().toString() : day = dat.getDate().toString();
                    form.time_tracker_date.value = year + '-' + month + '-' + day;
                }
            });
    } else {
        // function is called from the calendar widget. the calendar could only send a reference to itself, so we have
        // to find the form manually..
        var cal = obj;
        var form = cal.params.inputField.form;
        updateTTControllerForm(form);
    }
}

// ================== booking_form helpers ============================

function updateBookingHours(name) {
    var start_field = $(name + "_start_time");
    var stop_field = $(name + "_stop_time");
    var spent_field = $(name + "_spent_time");

    var start = start_field.value;
    var stop = stop_field.value;
    // if the stop-time looks smaller than the start-time, we assume a booking over midnight
    if (timeString2sec(stop) < timeString2sec(start)) {
        var temp = calcBookingHelper(start, "24:00", 1);
        spent_field.value = calcBookingHelper(stop, temp, 2);
    } else {
        spent_field.value = calcBookingHelper(start, stop, 1);
    }
}

function updateBookingStop(name) {
    var start_field = $(name + "_start_time");
    var stop_field = $(name + "_stop_time");
    var spent_field = $(name + "_spent_time");

    stop_field.value = calcBookingHelper(start_field.value, spent_field.value, 2);
}

function updateBookingProject(name) {
    var issue_id_field = $(name + "_issue_id");
    var project_id_field = $(name + "_project_id");
    var project_id_select = $(name + "_project_id_select");

    var issue_id = issue_id_field.value;
    if (issue_id.blank()) {
        project_id_select.enable(); // TODO get this element!!
        issue_id_field.parentNode.removeClassName('invalid');
    } else {
        new Ajax.Request('/issues/' + issue_id + '.json?',
            {
                method:'get',
                onSuccess:function (transport) {
                    issue_id_field.parentNode.removeClassName('invalid');
                    var issue = transport.responseJSON.issue;
                    if (issue == null) {
                        project_id_select.enable();
                    } else {
                        project_id_select.disable();
                        project_id_field.value = issue.project.id;
                        for (i = 0; i < project_id_select.length; i++) {
                            if (project_id_select[i].value == issue.project.id) project_id_select[i].selected = true;
                        }
                    }
                },
                onFailure:function () {
                    project_id_select.enable();
                    issue_id_field.parentNode.addClassName('invalid');
                }
            });
    }
}

function timeString2sec(str) {
    if (str.match(/\d\d?:\d\d?:\d\d?/)) {     //parse general input form hh:mm:ss
        var arr = str.strip().split(':');
        return new Number(arr[0]) * 3600 + new Number(arr[1]) * 60 + new Number(arr[2]);
    }
    if (str.match(/\d\d?:\d\d?/)) {     //parse general input form hh:mm:ss
        var arr = str.strip().split(':');
        return new Number(arr[0]) * 3600 + new Number(arr[1]) * 60;
    }
    // more flexible parsing for inputs like:  12d 23sec 5min
    var time_factor = new Hash({"s":1, "sec":1, "m":60, "min":60, "h":3600, "d":86400});
    var sec = 0;
    var time_arr = str.match(/\d+\s*\D+/g);
    time_arr.each(function (item) {
        item = item.strip();
        var num = item.match(/\d+/);
        var fac = item.match(/\D+/)[0].strip().toLowerCase();
        if (time_factor.get(fac)) {
            sec += num * time_factor.get(fac);
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
    var h = (val / 3600).floor();
    var m = ((val - h * 3600) / 60).floor();
    var s = (val - (h * 3600 + m * 60)).floor();
    h < 10 ? h = "0" + h.toString() : h = h.toString();
    m < 10 ? m = "0" + m.toString() : m = m.toString();
    s < 10 ? s = "0" + s.toString() : s = s.toString();
    while (calc == 2 && h > 23) h = h - 24;    //stop_time should be between 0-24 o clock
    return h + ":" + m + ":" + s;
}
