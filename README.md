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
* ruby (at least 1.9.3, tested mostly in 2.3.1)
* these gems are required:
```
gem install xml-simple hashdiff
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

That execution is comprised of 2 interactions: `hadoop271_nohb_nozk_instance` and `hadoop_instance_install`.
The first one is defined in terms of what a user has to decide or get to install a Hadoop instance:
a xml file layouting the cluster, the Hadoop tarball, and the name they want to give the instance (in the 
next section we show how to define that interaction, here only what it does). `hadoop_instance_install`
installs the hadoop instance assuming some things are defined (e.g, those defined by `hadoop271_nohb_nozk_instance`).


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

because  `hadoop_instance_install` is somehow defined to react to the definition of a property which `prefix=/root/` defines (`setup_script_path_prefix`, in this case) . Other interactions, like `pwd` or `date` -- just literals, are not defined to react on the same property -- they are kind of "naive" interactions.

This way onwards, it is possible to, departing from a very naive interaction (ie, basically hardcoded script)
to grow and build more trustworthy interactions (that will react on things previously defined). The `hadoop271_nohb_nozk_instance`, when first coded, didn't, a priori downloaded the needed files. It would require a `file_download` interaction to be called after its definition. But, since they're are required dependencies, the interactions were improved to make it try to download that file (if the file exists, it won't override it). At some point, it was introduced a interaction that blocks the terminal while the nodes aren't UP. Before, if a node was rebooting, the `hadoop_instance_install`  would certainly not produce its defined effect -- to install a hadoop instance.

Defining Interactions - Composite Pattern and how we use them for Regression Tests:
----------

Let's have a look at **definition of the interaction `hadoop271_nohb_nozk_instance`**:
```
  "hadoop271_nohb_nozk_instance" : {
    "instance_name"               : "hadoop271_nohb_nozk",
    "interactions"                : ["hadoop-2.7.1.tar.gz", "hadoop-2.7.1-no_hbase_no_zk.xml", "hadoop_bigdata_instance"],
    "comment"                     : ""
  },
```

That means that, **running `hadoop271_nohb_nozk_instance` is equivalent of running the sequence `hadoop-2.7.1.tar.gz,hadoop-2.7.1-no_hbase_no_zk.xml,hadoop_bigdata_instance` with the property `instance_name` set to `hadoop271_nohb_nozk`**.

Running `hadoop-2.7.1.tar.gz` is equivalent of running `file_download` and `hadoop-2.7.1`, with some more properties set:

```
  "hadoop-2.7.1.tar.gz": {
    "tool_tarball"                : "hadoop-2.7.1.tar.gz",
    "tool_release"                : "2.7.1",
    "download_url"                : "http://support.brightcomputing.com/bigdata/hadoop-2.7.1.tar.gz",
    "filename"                    : "hadoop-2.7.1.tar.gz", 
    "interactions" : ["file_download", "hadoop-2.7.1"],
    "comment"                     : ""
  },
```



Running `file_download` is equivalent of running a command that reacts on the `download_url`  property being set:
```
  "file_download": {
    "command": [
      { "literal"      : "wget -nv -c " },
      { "replaceQuoted": "download_url" },
      { "literal"      : " --output-document=" },
      { "replaceQuoted": "filename" }
    ]
  },
```

In the end, after all the tree is computed, **running `hadoop271_nohb_nozk_instance` will, indeed, run this sequence of interactions**:

```
    "hadoop271_nohb_nozk_instance",
    "hadoop-2.7.1.tar.gz",
    "file_download",
    "hadoop-2.7.1",
    "hadoop",
    "empty_namespace_tool_setup",
    "hadoop-2.7.1-no_hbase_no_zk.xml",
    "file_download",
    "hadoop_bigdata_instance",
    "set_hadoop_as_traditional_namespace"
```

All the interactions in that sequence just sets properties; only `file_download` actually has a command to run. Therefore, the resulting script is:

```
wget -nv -c "http://support.brightcomputing.com/bigdata/hadoop-2.7.1.tar.gz" --output-document="hadoop-2.7.1.tar.gz"
wget -nv -c "https://raw.githubusercontent.com/Bright-Computing/interactions/master/bigdata_instances_xmls/hadoop-2.7.1-no_hbase_no_zk.xml" --output-document="hadoop-2.7.1-no_hbase_no_zk.xml"
```

Note that `file_download` is run twice. The second time, it will download the url set by the interaction `hadoop-2.7.1-no_hbase_no_zk.xml`:

```
  "hadoop-2.7.1-no_hbase_no_zk.xml" : {
    "download_url"      : "https://raw.githubusercontent.com/Bright-Computing/interactions/master/bigdata_instances_xmls/hadoop-2.7.1-no_hbase_no_zk.xml",
    "filename"          : "hadoop-2.7.1-no_hbase_no_zk.xml",
    "interactions"      : ["file_download"],
    "comment"                     : ""
  },
```

After the tree is computed, **running `hadoop_instance_install` will run this sequence of interactions**:


```
    "hadoop_instance_install",
    "hadoop_bigdata_instance",
    "set_hadoop_as_traditional_namespace",
    "instance_install",
    "wait_for_nodes_up",
    "current_as_shell",
    "while_command",
    "instance_install_when_nodes_up"
```

Only `while_command` and `instance_install_when_nodes_up` have commands to run; the others just set properties. Then, the resulting script is:
```
  while [ "$( cmsh -c "device list" | egrep "Node.*\[ *(DOWN|INSTALLING|INSTALLER_CALLINGINIT) *\]" | egrep -v "((Unassigned))" | wc -l)" != "0" ] ; do echo Node status ; cmsh -c "device list" | egrep "Node.*\[ *(DOWN|INSTALLING|INSTALLER_CALLINGINIT) *\]" ;  sleep 5s ; done  

""""cm-hadoop-setup -c ""
```

Note that `cm-hadoop-setup` doesn't know which xml file to use as parameter, because `instance_install_when_nodes_up` reacts on the property `filename`, that was not set before (undefined property is always replaced by an empty string).

After the tree is computed, **running `hadoop271_nohb_nozk_instance,hadoop_instance_install` will run this sequence of interactions**:

```
    "hadoop271_nohb_nozk_instance",
    "hadoop-2.7.1.tar.gz",
    "file_download",
    "hadoop-2.7.1",
    "hadoop",
    "empty_namespace_tool_setup",
    "hadoop-2.7.1-no_hbase_no_zk.xml",
    "file_download",
    "hadoop_bigdata_instance",
    "set_hadoop_as_traditional_namespace",
    "hadoop_instance_install",
    "hadoop_bigdata_instance",
    "set_hadoop_as_traditional_namespace",
    "instance_install",
    "wait_for_nodes_up",
    "current_as_shell",
    "while_command",
    "instance_install_when_nodes_up"
```
which is **exactly the sum of each of sequences run by the interactions `hadoop271_nohb_nozk_instance` and `hadoop_instance_install`**. The generated scripts are the same:

```
wget -nv -c "http://support.brightcomputing.com/bigdata/hadoop-2.7.1.tar.gz" --output-document="hadoop-2.7.1.tar.gz"
wget -nv -c "https://raw.githubusercontent.com/Bright-Computing/interactions/master/bigdata_instances_xmls/hadoop-2.7.1-no_hbase_no_zk.xml" --output-document="hadoop-2.7.1-no_hbase_no_zk.xml"
  while [ "$( cmsh -c "device list" | egrep "Node.*\[ *(DOWN|INSTALLING|INSTALLER_CALLINGINIT) *\]" | egrep -v "((Unassigned))" | wc -l)" != "0" ] ; do echo Node status ; cmsh -c "device list" | egrep "Node.*\[ *(DOWN|INSTALLING|INSTALLER_CALLINGINIT) *\]" ;  sleep 5s ; done  

""""cm-hadoop-setup -c "hadoop-2.7.1-no_hbase_no_zk.xml"
```
But, this time `cm-hadoop-setup` knows which  use as parameter, because the `filename` property was set by `hadoop-2.7.1.tar.gz` and later overridden by `hadoop-2.7.1-no_hbase_no_zk.xml`.

An interaction can be defined in terms of other interactions, following the composite design pattern, and that allow sequences of interactions to be easily added, making life easier for growing the complexity of tests. E.g, have a look on the interaction `multiple_bigdata_tools_test`, composed of 44 other interactions:
```
  "multiple_bigdata_tools_test" : {
    "interactions": [
      "comment:clean up eventual test run before this",
      "multiple_bigdata_tools_test_cleanup",

      "comment:install hadoop instance, having 2.7.1 version number, removing it before if needed",
      "hadoop271_nohb_nozk_instance","bigdata_instance_install",

      "comment:install tools on that instance; the first has to be zookeeper or tools like hbase won't work",
      "set_zookeeper_basic_ensemble","zookeeper-3.4.6.tar.gz","tool_install",
      "set_hive_basic_ensemble","hive_metastore_setup", "apache-hive-1.2.1-bin.tar.gz","tool_install",
      "set_hbase_basic_ensemble","hbase-1.2.0-bin.tar.gz","tool_install",
      "set_spark_basic_ensemble","spark-1.5.1-bin-hadoop2.6.tgz","tool_install",
      "set_pig_basic_ensemble","pig-0.14.0.2.2.9.0-3393.tar.gz","tool_install",

      "comment:sed the service files to simulate that they're written without the symlinky technique",
      "bigdata_update_service_files_using_defaults",

      "comment:test tools on that instance",
      "spark-1.5.1-bin-hadoop2.6.tgz", "spark_example_pi_1","spark_submit_job",

      "comment:update the tools on that instance to a newer version",
      "set_zookeeper_basic_ensemble","zookeeper-3.4.8.tar.gz","tool_update",
      "set_hive_basic_ensemble","apache-hive-2.1.1-bin.tar.gz","tool_update",
      "set_hbase_basic_ensemble","hbase-1.3.0-bin.tar.gz","tool_update",
      "set_spark_basic_ensemble","spark-1.6.0-bin-hadoop2.6.tgz","tool_update",
      "set_pig_basic_ensemble","pig-0.16.0.tar.gz","tool_update",

      "comment:test updated tools on that instance",
      "spark-1.6.0-bin-hadoop2.6.tgz", "spark_example_pi_1","spark_submit_job",

      "comment:simulate failure to upgrade the hadoop instance to 2.7.2",
      "node001","simulate:make_hadoop_non_upgradable_reversible",
      "hadoop-2.7.2.tar.gz","tool_upgrade_explicit",
      "node001","simulate:make_hadoop_non_upgradable_revert",
      "hadoop-2.7.1","interactions.rb","hadoop_wordcount_example",

      "comment:succeed to upgrade the hadoop instance to 2.7.2",
      "hadoop-2.7.2.tar.gz","tool_upgrade_explicit",
      "hadoop-2.7.2","interactions.rb","hadoop_wordcount_example",

      "comment:update the tools on that instance to an older version",
      "set_zookeeper_basic_ensemble","zookeeper-3.4.6.tar.gz","tool_update",
      "set_hive_basic_ensemble","apache-hive-1.2.1-bin.tar.gz","tool_update",
      "set_hbase_basic_ensemble","hbase-1.2.0-bin.tar.gz","tool_update",
      "set_spark_basic_ensemble","spark-1.5.1-bin-hadoop2.6.tgz","tool_update",
      "set_pig_basic_ensemble","pig-0.14.0.2.2.9.0-3393.tar.gz","tool_update",

      "comment:test updated tools on that instance",
      "spark-1.5.1-bin-hadoop2.6.tgz", "spark_example_pi_1","spark_submit_job",

      "comment:test Spark instance, test, update, test again",

      "sparkStandalone_instance","bigdata_instance_install","spark_example_pi_1","spark_submit_job",
      "set_spark_basic_ensemble","spark-1.6.0-bin-hadoop2.6.tgz","tool_update",
      "spark_example_pi_1","spark_submit_job",

      "unsed"
    ],
    "comment": ""
  },
```
As of today, that **44-interaction sequences will spawn a sequence of 2994 interactions**.
`multiple_bigdata_tools_test`
basically installs specific versions of certain tools that work together with Spark or Hadoop. Repeating
tests with a slightly different case is just matter of adding some new interactions (in general 
to download a new version of a tar.gz, eg) and deriving that test. Or, we can call that interaction
twice, to test if it still succeeds.

In the end, once defined, the interactions are easily
combined to form different test cases. Very commonly we freeze an interaction derived from 
`multiple_bigdata_tools_test` and link its name to a JIRA issue. This way, if anytime later we want
to test if the test that validated a solution of an issue still works, we just need to run
that frozen interaction.

