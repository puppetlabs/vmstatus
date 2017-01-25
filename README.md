# vmstatus

vmstatus correlates virtual machines in VMware vSphere against vmpooler and Jenkins jobs in order to understand which VMs are doing useful work. It groups virtual machines into one of the following states:

![vmstatus](./vmstatus.png)

| State | Description |
|--------|-------------|
| `queued` | VM is associated with a queued Jenkins job |
| `building` | VM is associated with a building Jenkins job |
| `ready` | VM is idle in vsphere and is ready to be checked-out |
| `adhoc` | VM is checked out, but is not associated with any Jenkins job |
| `aborted` | VM is checked out and is associated with an aborted Jenkins job |
| `passed` | VM is checked out and is associated with a passing Jenkins job |
| `failed` | VM is checked out and is associated with a failed Jenkins job |
| `disabled` | VM is checked out and is associated with a disabled Jenkins job |
| `deleted` | VM is checked out and is associated with a deleted Jenkins job |
| `orphaned` | VM is running but there is no record in vmpooler |

The `queued` and `building` states indicate useful work, since the VM is in vSphere and is associated with a currently running Jenkins job. All other states are unuseful from a production CI perspective.

## Requirements

Tested on MRI Ruby 2.1 and newer.

Depends on the following gems:

* redis
* rest-client
* concurrent-ruby
* ruby-progressbar
* slop
* colorize
* statsd-ruby >= 1.3.0
* rbvmomi

## Usage

### Summary

```
$ bundle exec vmstatus summary --host vcenter --user user@foo.com
Querying vsphere 'vcenter' for VMs in cluster 'acceptance1' in datacenter 'dc1'
Processing 1657 VMs, ignoring 243 templates
Time: 00:01:00 ====================================================================================== 100% Progress

Number of VMs associated with running Jenkins jobs
      0 queued
     90 building

Number of VMs associated with completed Jenkins jobs
     78 passed
     42 failed
     35 aborted
      0 disabled
      2 deleted

Number of VMs not associated with any vmpooler
    118 orphaned

Number of VMs not associated with any Jenkins job
    142 adhoc
   1150 ready
      0 unknown

Efficiency 5.4%, 90 out of 1657 VMs are doing useful work
```

### List
