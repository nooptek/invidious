'use strict';
var ivsb_actions = {};
var ivsb_segments = [];

function ivsbCreateProgressBarSegments () {
    var duration = player.duration();

    for (const seg of ivsb_segments) {
        if (duration > 0)
            break;
        duration = seg.videoDuration;
    }
    if (duration <= 0)
        return;

    var pb = document.createElement('div');
    pb.classList.add('ivsb_progressbar');

    for (const seg of ivsb_segments) {
        if (ivsb_actions[seg.category] == "none")
            continue;

        var el = document.createElement('div');

        el.classList.add('ivsb_segment');
        el.classList.add('ivsb_' + seg.category);
        el.style.left = seg.segment[0] / duration * 100 + '%';
        el.style.width = (seg.segment[1] - seg.segment[0]) / duration * 100 + '%';

        pb.appendChild(el);
    }

    document.querySelector('.vjs-progress-holder').appendChild(pb);
}

function ivsbSkipSegment () {
    var currentTime = player.currentTime();

    for (const seg of ivsb_segments) {
        if (ivsb_actions[seg.category] != "skipauto")
            continue;

        if (currentTime > seg.segment[0] && currentTime < seg.segment[0] + .5) {
            player.currentTime(seg.segment[1]);
            break;
        }
    }
}

function ivsbBrowserPluginPresent () {
    return !!document.getElementById('sbCategoryColorStyle');
}

function ivsbParseSegments (response) {
    ivsb_segments = response;
    if (ivsb_segments.length <= 0)
        return;

    // check a second time in case the browser plugin was slower than us
    if (ivsbBrowserPluginPresent())
        return;

    ivsbCreateProgressBarSegments();
    player.on('timeupdate', ivsbSkipSegment);
}

function ivsbPlayerInit () {
    if (ivsbBrowserPluginPresent()) {
        // SponsorBlock browser plugin detected, disable Invidious native support
        return;
    }

    helpers.xhr('GET', '/ivsb/' + video_data.id, {
        timeout: 4000,
        retries: 3,
        entity_name: 'ivsb',
    }, {
        on200: ivsbParseSegments,
    });
}

function ivsbWindowInit () {
    ivsb_actions = video_data.preferences.sponsorblock_actions;

    if (player.duration() === undefined)
        player.on('loadedmetadata', ivsbPlayerInit);
    else
        ivsbPlayerInit();
}

addEventListener('load', ivsbWindowInit);
