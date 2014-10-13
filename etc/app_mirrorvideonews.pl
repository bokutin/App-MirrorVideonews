+{
    username => 'foo',
    password => 'bar',
    save_dir => '/Users/USER/Movies/VideoNews',
    archives_dirs => [
        '/Volumes/ExternalHDD/Movies/Videonews',
    ],
    download_media_types => [
        "FLV",
        "WMV",
        "iPhone",
        "YouTube",
    ],

    max_jobs => 2, # phantomjs + ffmpeg
};
