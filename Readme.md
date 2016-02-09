mkvm.rb
=======

A ruby wrapper around the hammer cli for foreman to create vms consistently, predictably, and programmatically.

----------

Main features:
---
* Adds cli options/arguments for VMware attributes hammer lacks/stuffs into ```compute-attributes=cpus=2,memory=512``` etc.
* Adds ability to use config files to create "profiles" of vms, providing some/all cli options (A config for testing systems, a config for production systems, etc)
* Can be called in a wizard like manner, prompting for input with menus (available Os's, partition tables, etc)

Setup:
---
* ```bundler install``` (or, install via rpms/hammer_cli_foreman gem directly)

* ```~/.hammer/cli.modules.d/foreman.yml``` should contain something like:
```
:foreman:
    :enable_module: true
    :host: 'https://localhost/'
    :username: 'admin'
    :password: 'changeme'
```
substituting your info. Ideally make this file only accessible by your user. Sadly, we cannot YET pass this into foreman/prompt for it if its missing.
* 
