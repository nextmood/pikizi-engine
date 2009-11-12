// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults


function select_toggle(name, value)
    {
        check_boxes = document.getElementsByName(name + '[]');
        for(var i=0; i<check_boxes.length; i++) { check_boxes[i].checked = value; }
    }
