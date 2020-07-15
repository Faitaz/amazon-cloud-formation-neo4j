# Neo4j Google Cloud Launcher

This is a default GCP Debian 9 based image, with the neo4j enterprise
package installed.  To make configuration of CC easy, a number of shell
add-ons have been installed.

# A Warning

Google's launcher documentation isn't great in spots, and there are a bunch of small
WTFs.  

POCs:

* Google Marketplace Ops Team cloud-partner-onboarding@google.com 
* Previous technical POC Emily Bates <emilybates@google.com> who was super helpful,
and can answer technical questions, but may have moved on.
* Tor Ulstein <toruls@google.com> previously copied on threads related to our solution

Read this entire README carefully, there is a lot of info on gotchas and specific instructions
that you won't be able to find via google.

## Jinja Gotchas

Jinja templates in particular are kind of tricky, because sometimes you must reference 
the same data in many different places.  For example, to add a variable a user can specify
via the config, it must be in the main jinja file, the schema, and the display template.
And it has to be in two spots in the schema!  (Required, and properties).  The package
we use was generated by google at their recommendation and customized.  I'm not loving jinja.

## Solution Manager Gotchas

You can get to the solution manager by going to the `launcher-public` project, left nav
choose "Cloud Launcher", then "Partner Portal", then "Solutions".  Uploading a zipped
package is pretty buggy, and you will sometimes have to reload the browser, and upload 
multiple times to get rid of nagging validation errors that aren't correct.  These issues
have been reported to google.

# GCloud API Requirements

Needed if you're trying to replicate in a different google project. If you're using
the two provided google projects, you can skip this.

```
gcloud services enable runtimeconfig.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable deploymentmanager.googleapis.com
```

# Quickstart / Deploy Instructions

A CC is deployed by creating 3 instances of the same VM, each with identical
configuration.  Be exact in passing of properties as documented below, gcloud is
very fussy about those.

```
gcloud config set project my-project-id
gcloud deployment-manager deployments create my-cluster \
    --template solutions/causal-cluster/neo4j-causal-cluster.jinja \
    --properties "clusterNodes:'3',readReplicas:'2'"
```

This does the same that Google Launcher does, without the GUI config.

If you want to test drive the GUI config, after uploading the package to the solution portal
(just ZIP the deployment manager directory and upload it), then you need to use this URL.

```
https://console.cloud.google.com/launcher/details/neo4j-public/neo4j-enterprise-causal-cluster?preview=neo4j-public%2Fneo4j-enterprise-causal-cluster&project=launcher-development-191917
```

Undocumented gotcha -- note the project ID in the URL.  The public launcher project has no
quota, so launching VMs into it will fail every time.  It's only there to house public images.

# Important Deployment Files

- `neo4j-causal-cluster.jinja` is the entrypoint for how a cluster gets deployed.
- `neo4j-causal-cluster.jinja.display` contains instructions to Google's Launcher app on how to lay out the UI, what users can pick, etc.
- `neo4j-causal-cluster.jinja.schema` contains the visual elements users get asked to provide, plus defines inputs/outputs for the entire deploy process.  This is also where you do things like specify options for how many nodes could be deployed, set a minimum machine type, etc.

# Preparing a new Image (i.e. upgrading all of this)

See the packer directory; this prepares new images, follow directions there to copy
an image to the appropriate project and associate the right license with it.

# Adjusting the Deployment Manager Files

These directions only apply after the image has been prepared according to the points
above and the packer directory.

In the `solutions/causal-cluster` directory, there are jinja template files that describe
the Deployment Manager templates used to control the causal cluster offering on GCP Marketplace.

At a minimum, these files need to be updated for legacy reasons, referencing the new image
that has been copied over to the launcher-public project
* c2d_deployment_configuration.json
* neo4j-causal-cluster.jinja
* neo4j-causal-cluster.jinja.display

Those files contain references to the image.

# Packaging for the Marketplace

* Go into the solutions/causal-cluster directory and zip the package contents: `zip -9r pkg.zip *`
* In GCP, you need access to the `launcher-public` project.  Switch to that project.
* On the left toolbar, select marketplace.
* Select the "Partner Portal" link which will only appear under the `launcher-public` project.
* Select the solution we're editing (neo4j causal cluster, VM based)
* Find the link within that page to upload the package (the ZIP we prepared)
* **DO NOT EDIT ANY OTHER FIELD IN THE UI**.  All of those changes will be overridden
by metadata in the zip package.  If you find a field in the UI you want to change, instead
change it in the jinja template files in this repo and change it by zipping/uploading the
package.
* Test and submit.

# Making Public the Deployment Manager Files

There is a google storage bucket called `neo4j-deploy` which resides here:
https://console.cloud.google.com/storage/browser/neo4j-deploy?project=launcher-public&organizationId=1061230109173

There should be a subdirectory for every deployed version (i.e. 3.5.5) and the jinja templates are copied to this location like so:

```
export VERSION=3.5.16
gsutil -m cp -r solutions/causal-cluster/* gs://neo4j-deploy/$VERSION/causal-cluster/
```

# Removing a Deployment

Removing the deployment autokills/deletes the underlying VMs.
**But not their disks** since we've marked the disks to be persistent
by default.

Note the disk delete statement here is risky, make sure you don't have
clashing named disks.  This is quick instruction only, take care when
deleting disks.

```
# Kill/delete VMs.
gcloud deployment-manager deployments delete my-cluster

# Remove persistent disks.
for disk in `gcloud compute disks list --filter="name:my-cluster-vm-*" --format="get(name)"` ; do 
  gcloud compute disks delete "$disk" ; 
done
```

# Google Image

## Metadata

Google deploy manager jinja templates allow us to configure key/values on the image.  This metadata in turn can be fetched inside of the VM from a metadata server.

The `/etc/neo4j/neo4j.template` file controls how image metadata impacts neo4j server configuration.  Prior to neo4j starting up, these values are fetched from google's metadata server, and substituted into neo4j.conf via the template.   See `pre-neo4j.sh` for the mechanics of how this works.

Only a limited number of necessary options are configurable now, the rest
is TODO.

The result of all of this is that by tweaking the deployment manager
template, you can control the entire cluster's identical config.

# Debian Instance Service Configuration

The image is based on Debian 9, and the standard neo4j debian package, so you should be using `systemctl` inside of the VM.

[Relevant docs](https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units)

Status can be obtained via `systemctl status neo4j.service`

Normally, the command for the neo4j service is `neo4j console`.  That has been placed in pre-neo4j.sh.

Make sure also that `/usr/share/neo4j/conf/neo4j.conf` is a symlink to `/etc/neo4j/neo4j.conf`

So the system service profile (`systemctl edit --full neo4j.service`) instead calls `pre-neo4j.sh`.   This part is critical to be maintained between service maintenance and package upgrades.

# Limitations and TODO

## Network Locality

Currently, all node instances must be deployed in the same subnet, same zone/region on GCP.
This is because they find each other by local and GCP internal DNS name resolution. This can
be overcome if you set up separate DNS or static IP addresses for new nodes, and then ensure
that the `causal_clustering_initial_discovery_members` metadata setting contains the right hosts.