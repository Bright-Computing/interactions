<!--
Copyright 2017 Bright Computing Holding BV.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-->

# interactions
Tool for automatizing the generation of scripts

Requisites
----------
* ruby (at least 1.9.3)
* these gems are required:
```
require "rubygems"
require "open3"
require "json"
require "pp"
require 'optparse'
require "singleton"
require 'xmlsimple'
require 'hashdiff'
```



Basics
----------
Best start with examples -- the interactions `date`  or `df` simply execute the bash commands, without setting anything special:
```
ruby  interactions.rb -i date,df,date -d live,warning
date 
# Tue Mar  7 13:12:57 CET 2017
df 
# Filesystem     1K-blocks     Used Available Use% Mounted on
# /dev/sda1      134537480 99553588  28126728  78% /
# udev               10240        0     10240   0% /dev
# tmpfs            1614236   159580   1454656  10% /run
date 
# Tue Mar  7 13:12:57 CET 2017
```

If you open the file `interactions.json` you see that they're defined just by a literal:
```
  "df": {
    "command": [
      { "literal"      : "df " }
    ]
  },
  "date": {
    "command": [
      { "literal"      : "date " }
    ]
  },
  "pwd": {
    "command": [
      { "literal"      : "pwd " }
    ]
  },
```

But they give an idea of what `interactions` are about. `interactions`, although a general purpose tool,
was started for testing the big data plugin of Bright Cluster Manager. A simple `interactions` execution
that does something more concrete is:

```
ruby  interactions.rb -i hadoop271_nohb_nozk_instance,hadoop_instance_install -d live,warning
```

It installs installs the `hadoop271_nohb_nozk` instance, as a hadoop instance (downloading the xml file defined as `download_url` and renaming it as `filename`), using the `cm-hadoop-setup` reacheable in the system's `PATH`.

After calculating the dependencies and execution tree, `interactions.rb` generates and executes the below script
to achieve the defined effect:
```
wget -nv -c "http://support.brightcomputing.com/bigdata/hadoop-2.7.1.tar.gz" --output-document="hadoop-2.7.1.tar.gz"
wget -nv -c "https://raw.githubusercontent.com/Bright-Computing/interactions/master/bigdata_instances_xmls/hadoop-2.7.1-no_hbase_no_zk.xml" --output-document="hadoop-2.7.1-no_hbase_no_zk.xml"
  while [ "$( cmsh -c "device list" | egrep "Node.*\[ *(DOWN|INSTALLING|INSTALLER_CALLINGINIT) *\]" | egrep -v "((Unassigned))" | wc -l)" != "0" ] ; do echo Node status ; cmsh -c "device list" | egrep "Node.*\[ *(DOWN|INSTALLING|INSTALLER_CALLINGINIT) *\]" ;  sleep 5s ; done  
  """"cm-hadoop-setup -c "hadoop-2.7.1-no_hbase_no_zk.xml"
```


Adding the interaction `prefix=/root/` before `hadoop_instance_install`:
```
ruby  interactions.rb -i hadoop271_nohb_nozk_instance,prefix=/root/,hadoop_instance_install -d live,warning
```
will change the path to search the executables for that interaction:
```
wget -nv -c "http://support.brightcomputing.com/bigdata/hadoop-2.7.1.tar.gz" --output-document="hadoop-2.7.1.tar.gz"
wget -nv -c "https://raw.githubusercontent.com/Bright-Computing/interactions/master/bigdata_instances_xmls/hadoop-2.7.1-no_hbase_no_zk.xml" --output-document="hadoop-2.7.1-no_hbase_no_zk.xml"
  while [ "$( cmsh -c "device list" | egrep "Node.*\[ *(DOWN|INSTALLING|INSTALLER_CALLINGINIT) *\]" | egrep -v "((Unassigned))" | wc -l)" != "0" ] ; do echo Node status ; cmsh -c "device list" | egrep "Node.*\[ *(DOWN|INSTALLING|INSTALLER_CALLINGINIT) *\]" ;  sleep 5s ; done  
"/root/"""cm-hadoop-setup -c "hadoop-2.7.1-no_hbase_no_zk.xml"
```

because  `hadoop_instance_install` is somehow defined to react to the definition of the attribute `setup_script_path_prefix` -- which `prefix=/root/` defines. Other interactions, like `pwd` or `date` -- just literals, are still very naive.

This way onwards, it is possible to, departing from a very naive interaction (ie, basically hardcoded thing) to grow and build more trustworthy interactions (that will react on things previously defined). The `hadoop271_nohb_nozk_instance`, when first coded, didn't, a priori downloaded the needed files. It would require a `file_download` interaction to be called after its definition. But, since they're are required dependencies, the interactions were improved to make it try to download that file (if the file exists, it won't override it). At some point, it was introduced a interaction that blocks the terminal while the nodes aren't UP. Before, if a node was rebooting, the `hadoop_instance_install`  would certainly not produce its defined effect -- to install a hadoop instance.
