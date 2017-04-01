## Overview ##

Why pay (twice) for cloud storage when our taxes already pay for storage in NSA datacenters?

**nsafs** allows you to use the NSA as a cloud storage provider by exposing data storage/retrieval functions in a [FUSE](https://github.com/libfuse/libfuse) filesystem.


## How it Works ##

When you save a file to an nsafs-mounted directory, the contents are sent to a (configurable) PRISM target company's servers in an HTTP request. The HTTP request itself may result in an HTTP error response, but we can safely assume the data is simultaneously ingested and stored on NSA servers at that point.

When saving data, nsafs also automatically files a FOIA request for that data using an API provided by [MuckRock](https://www.muckrock.com/) in anticipation of later retrieval.

When reading the contents of a file, nsafs checks to see if a matching FOIA response has been received, and if it has, the contents of the attached document are returned to the user.


## Requirements ##

- Ruby 2.x
- libfuse
- An account with [MuckRock](https://www.muckrock.com/)


## Setup ##

### With Docker Image ###

A basic [docker image](https://hub.docker.com/r/freedomtools/nsafs/) is available on Docker Hub. To run it in a container, do this:

`docker run -it --rm --cap-add SYS_ADMIN --cap-add MKNOD --device /dev/fuse -e "MOUNT_OPTIONS={MOUNT OPTIONS}" freedomtools/nsafs`

### Running Directly ###

- Make sure you have Ruby installed, along with libfuse-dev.
- Install gem dependencies with `bundle install`

Then start with:

`bundle exec ruby nsafs.rb {MOUNT POINT} -o {MOUNT OPTIONS} &`

### {MOUNT OPTIONS} ###

Whether running nsafs directly or in a docker container, you'll need to replace `{MOUNT OPTIONS}` with a comma-separated list of configuration options. These include:

- `username` **(required)** Your MuckRock username
- `api_token` **(required)** Your MuckRock API token. You can obtain a token by running the provided `get_api_token.rb` script.
- `endpoint` The company to use for data sharing with the NSA. Must be one of: `aol`, `apple`, `facebook`, `google`, `microsoft`, `paltalk`, `skype`, `yahoo`,  or `youtube`. Default: `aol`
- `wait` Time to wait (in seconds) for FOIA response before timing out. Default: `0` (timeout immediately if unavailable).

#### Example: ####

`username=citizenfour,api_token=abc123,wait=2592000`


## FAQ ##

#### Does this really work? ####
In theory, yes.

#### What file operations are supported? ####
nsafs supports basic write and read operations, though read operations currently suffer significant latency. Deletions are not permitted due to the NSA's current storage lifetime policies. Subdirectories are not currently supported.

#### What kind of performance can I expect? ####
Write throughput is really only limited by your internet connection speed. Read throughput is sporadic.

#### What about data integrity? ####
When data is retrieved, it may be presented in a format that differs from the original. For example, a simple ASCII text file written to nsafs could (upon retrieval) be represented as a PDF or Word document. Depending on the nature of the file's contents, significant portions may also be unreadable/redacted for the sake of national security.

#### What are the storage costs? ####
Apart from bandwidth usage, storage on nsafs is essentially free (provided as a public service and supported by tax revenue). Similar to Amazon's Glacier storage, there are greater costs associated with data retrieval.

FOIA requests can currently be purchased on MuckRock (Basic plan) in bundles of 4 for $20. You can try nsafs for free; the FOIA requests will just be saved as drafts.

By comparison, Amazon Glacier storage charges $0.01 per GB retrieved (standard), so nsafs may be more cost-effective for files over roughly 500 GB in size.

#### Doesn't the CIA already have backdoor access to my data? ####
Yes, good point. You can use nsafs in "CIA mode" by supplying the additional mount option `cia_mode=1`. This will effectively bypass the need to transmit any data over the network (at least to our knowledge) when writing data, since the CIA is presumably collecting the data transparently. Data retrieval is still performed via FOIA requests.

#### Is it secure? ####
Of course. What could possibly be more secure than the National **Security** Agency?

#### Does it keep my data private? ####
Uh-huh.



## License ##

Licensed under the MIT license.

## Contributing ##

Pull requests are welcome.

## Acknowledgements ##

Special thanks to Edward Snowden for inspiring this project.
