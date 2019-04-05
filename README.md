---
title: "dockerinoz - build containers that won't haunt you"
date: 2019-04-06T11:32:33Z
draft: true
tags: [ "dockerinoz", "docker", "dockerfile", "ruby", "tool"]
---

### dockerinoz - simple Dockerfile (security) best practices verification
**dockerinoz** is a very small and simple tool which allows you to verify the content of Dockerfiles against a given best practice. It's nothing more than a fancy grep using a bit more than just simple regular expressions.
This approach allows for _very_ quick verifications which is especially important when implementing **dockerinoz** into your build pipeline. It also makes **dockerinoz** super easy to modify and extend - especially as the rules are just regular expressions in a json file (rules.json).
<!--more--> 
The rules you will find in the related repository are based around the best practice recommendations outlined below. I strongly recommend to not just rely on my judgement, but tailor the rules to your needs.

Please also keep in mind that the information in this post and repository are just a snapshot in time. I haven't gotten around to update the guidance and rules in over a year. Please keep that in mind when considering the guidance and the tool.
And make sure to check <https://docs.docker.com/develop/develop-images/dockerfile_best-practices/>.

### Security Best Practices
Dockerfiles are made up of a collection of instructions which are being used to orchestrate the build process of a docker image/container. Some of the instructions allow the usage of shell commands which are run inside the container as part of the build process. A lot of the supported instructions can be used and abused in multiple ways which can lead to unexpected behaviour during build and runtime of a container. In order to reduce the risk of unexpected behaviour as well as to introduce some basic hardening around permissions, access management and verification of included/pulled resources, I recommend to follow some basic best practices outlined in the section below.

### Security Related Dockerfile Instructions Explained
> Note: The instructions RUN, CMD and ENTRYPOINT support two different forms, "shell" and "exec". Depending on which form is being chosen the behaviour of the given commands can be completely different. I refer to the "shell" and "exec" formats in the table below and recommend when to use which. Please refer to Dockerfile reference for more details.

| Instruction | Description / Recommendation | Examples |
|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| USER | The USER instruction switches the user context. It allows to change to a specific user which exists in the base image. It's typically used to drop root privileges before any files are being modified and services being started. Not using a USER instruction implies that root is being used. I strongly recommend to drop root privileges as soon as possible in a Dockerfile and never run any services/applications with root privileges. | <font color="green">USER app</font><br><font color="red">USER root</font> |
| WORKDIR | WORKDIR sets the working directory for the instructions RUN, CMD, ENTRYPOINT, COPY and ADD. I recommend to set a WORKDIR as otherwise you might face unexpected behavior which can result into unforeseen security issues. The WORKDIR needs to be accessible by the user set in the USER instruction. | <font color="green">WORKDIR /app</font><br><font color="red">WORKDIR /</font> |
| EXPOSE | EXPOSE is being used to expose, or, actually, to declare the intention to expose, ports from inside the container to the docker host. This is required when you have a service/application running inside the container which needs reachable via the network. I recommend to always only use high-ports (>1023) for listening services. This is because privileged ports (<1024) require root privileges to be bound and I do not want to run anything with root privileges in a container. | <font color="green">EXPOSE 8080 3128 1500</font><br><font color="red">EXPOSE 22 80 443</font> |
| MAINTAINER | This instruction is for informational purpose only. It can be used to set the MAINTAINER of a Dockerfile. Docker is expiring this instruction and recommends to use a LABEL instead:  LABEL maintainer=EMAIL@DOMAIN.COM | <font color="red">MAINTAINER employee@corp.com</font> |
| LABEL | The LABEL instruction can be used to add metadata to an image. I recommend to use the metadata in order to, at least, document the maintainer of the image/Dockerfile. | <font color="green">LABEL maintainer=employee@corp.com</font> |
| ADD | The ADD instruction copies new local files, directories or remote file URLs from a source and adds them to the file system of the image at the destination path. In addition, ADD does some magic around the extraction of specific tarballs, automatically creating folders and more. As the actual behavior cannot be reliably predicted I strongly recommend to NOT use ADD at all. Please use COPY instead. | <font color="red">ADD http.//www.unsecure.org/folder/file.tar.gz /</font> |
| SHELL | The SHELL instruction defines which shell is being used for the commands executed in the RUN, CMD, ENTRYPOINT instructions. I advice that you are very careful using the SHELL instruction and only use it if there is no other viable way to achieve your goal. The SHELL instruction can add complexity and unpredictability to a container build process and should therefore be avoided. | <font color="red">SHELL ["zsh", "-x"]</font> |
| ARG | ARG is being used to define variables you can pass into the Dockerfile during the build process. Please DO NOT use ARGs in order to pass in any sensitive content like secrets, passwords or keys to the build process/container. | <font color="green">ARG workdir=/tmp user=nobody</font><br><font color="red">ARG password=notSecure</font> |
| ENV | Is being used to set ENV variables which will be available in the running container. Please DO NOT use ENVs in order to pass in any sensitive content like secrets, passwords or keys in an unencrypted form to the container. | <font color="green">ENV workdir=/tmp user=nobody</font><br><font color="red">ENV password=notSecure</font> |
| CMD | CMD specifies the default command to be run on container startup. It can only be specified once and supports "shell" and "exec" format. I recommend to always use "exec" format and properly set the ENTRYPOINT instead of using the "shell" format. | <font color="green">CMD ["executable", "-param1", "-param2"]</font><br><font color="red">CMD executable -param1 -param2</font> |
| ENTRYPOINT | The ENTRYPOINT instruction defines which command/application is to be run on container startup. I recommend to always specify an ENTRYPOINT in "exec" format. The ENTRYPOINT should handle signals and can be used to prepare the environment before the actual application is being started by it. | <font color="green">ENTRYPOINT ["executable", "-param1", "-param2"]</font><br><font color="red">ENTRYPOINT executable -param1 -param2</font> |
| FROM | FROM specifies the base image used for this build. Please specify a specific version and do not use tags like ":latest". Not using a specific version can result in unexpected behaviour. | <font color="green">FROM base:1.4</font><br><font color="red">FROM base:latest<br>FROM base</font> |
| RUN | RUN instructions can be used to run specific commands in the container during the build process. I recommend to not run any commands which rely on potentially unstable/untrusted external resources like random github repositories or other http/s resources. Using official distribution (alpine, debian, ubuntu, ...) repositories and package management systems (pip, gem, npm, ...) is acceptable. Please always specify the specific version of packages and modules you install. | <font color="green">RUN set -ex; \\<br>apk --update add bash git jq build-base openssh findutils coreutils grep curl && \\<br>gem install aws-sdk -v 2.9.17 && \\<br>apk del build-base && \\<br>rm -rf /var/cache/apk/*;</font><br><font color="red">RUN curl http.//www.opscode.com/chef/install.sh \| sudo bash</font> |

### dockerinoz - the tool
You can just run **dockerinoz** against any Dockerfile like that:
`./dockerinoz.rb Dockerfile`
and for json output just add `--json` as the first argument. You can find a few examples below.
```
e-axe@kaylee:~/private/hacking/dockerinoz$ for i in $(find ../ -name Dockerfile); do \
  echo -en "--- $i ---\n"; \
  ./dockerinoz.rb $i ;\
done
--- ../googlecloud/google-cloud-sdk/.install/.backup/platform/ext-runtime/go/data/Dockerfile ---
High: No instruction has been identified to set the USER; this implies 'root'.
Low: No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour.
Low: There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer="maintainer@CORP.com".
--- ../googlecloud/google-cloud-sdk/.install/.backup/platform/ext-runtime/nodejs/data/Dockerfile ---
High: No instruction has been identified to set the USER; this implies 'root'.
Low: No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour.
Low: There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer="maintainer@CORP.com".
--- ../rails_redis_sqlite-hackit/guestbook/Dockerfile ---
High: No instruction has been identified to set the USER; this implies 'root'.
Low: No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour.
Low: There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer="maintainer@CORP.com".
High: GEM pkgs are being installed without version pinning. ["gem", "bundler"]
Info: A CMD/ENTRYPOINT is defined in 'shell' format. It is highly recommended to only use JSON format for these instructions. ["CMD", "bundle exec puma -C config/puma.rb"]
--- ../tools/radare2-3.1.0/Dockerfile ---
High: No instruction has been identified to set the USER; this implies 'root'.
Low: No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour.
Low: There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer="maintainer@CORP.com".
--- ../palpari/components/suricata/Dockerfile ---
High: No instruction has been identified to set the USER; this implies 'root'.
Low: No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour.
Low: There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer="maintainer@CORP.com".
High: An external resource is included/downloaded via plain HTTP. ["http://", "dl-cdn.alpinelinux.org"]
High: PIP pkgs are being installed without version pinning. ["pip3", "suricata-update"]
--- ../git/cutter/docker/Dockerfile ---
High: No instruction has been identified to set the USER; this implies 'root'.
Low: No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour.
Low: There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer="maintainer@CORP.com".
Medium: ADD is being used in this Dockerfile. Add can lead to unwanted behaviour. Please use COPY instead. ["ADD", "entrypoint.sh /usr/local/bin/entrypoint.sh"]
--- ../git/ws/autobahn/docker/autobahn/Dockerfile ---
High: No instruction has been identified to set the USER; this implies 'root'.
Low: No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour.
Low: There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer="maintainer@CORP.com".
High: PIP pkgs are being installed without version pinning. ["pip", "autobahntestsuite"]
--- ../git/honeytrap/vendor/golang.org/x/net/http2/Dockerfile ---
High: No instruction has been identified to set the USER; this implies 'root'.
Low: No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour.
Low: There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer="maintainer@CORP.com".
High: An external resource is included/downloaded via plain HTTP. ["http://", "curl.haxx.se"]
Medium: CURL/WGET is being used. This can introduce potentially dangerous and unexpected behaviour. Please pull those dependencies before the docker build and use COPY to add them to the container. ["wget", "http://curl.haxx.se/download/curl-7.45.0.tar.gz"]
--- ../git/honeytrap/Dockerfile ---
High: No instruction has been identified to set the USER; this implies 'root'.
Low: No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour.
Low: There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer="maintainer@CORP.com".
Medium: ADD is being used in this Dockerfile. Add can lead to unwanted behaviour. Please use COPY instead. ["ADD", ". /go/src/github.com/honeytrap/honeytrap"]
```

```
e-axe@kaylee:~/private/hacking/dockerinoz$ for i in $(find ../ -name Dockerfile); do \
  echo -en "--- $i ---\n"; \
  ./dockerinoz.rb --json $i | jq . ; \
done 
--- ../googlecloud/google-cloud-sdk/.install/.backup/platform/ext-runtime/go/data/Dockerfile ---
{
  "Dockerinoz_Report": {
    "dockerfile": "../googlecloud/google-cloud-sdk/.install/.backup/platform/ext-runtime/go/data/Dockerfile",
    "results": [
      {
        "serverity": "High",
        "description": "No instruction has been identified to set the USER; this implies 'root'."
      },
      {
        "serverity": "Low",
        "description": "No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour."
      },
      {
        "serverity": "Low",
        "description": "There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer=\"maintainer@CORP.com\"."
      }
    ]
  }
}
--- ../googlecloud/google-cloud-sdk/.install/.backup/platform/ext-runtime/nodejs/data/Dockerfile ---
{
  "Dockerinoz_Report": {
    "dockerfile": "../googlecloud/google-cloud-sdk/.install/.backup/platform/ext-runtime/nodejs/data/Dockerfile",
    "results": [
      {
        "serverity": "High",
        "description": "No instruction has been identified to set the USER; this implies 'root'."
      },
      {
        "serverity": "Low",
        "description": "No instruction has been identified to set the WORKDIR; This can result in unexpected behaviour."
      },
      {
        "serverity": "Low",
        "description": "There is no LABEL with a maintainer key specified. Please make sure to add a label like: LABEL maintainer=\"maintainer@CORP.com\"."
      }
    ]
  }
}
...
```
That's essentially it. Very quick and easy. Go and get it from [here](https://github.com/mytty-project/dockerinoz) (https://github.com/mytty-project/dockerinoz) if you are interested in giving it a spin.

part of <https://mytty.org>
