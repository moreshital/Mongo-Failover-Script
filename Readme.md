## ** Self Healing MongoDB Cluster**

We all love to sleep but what if in the middle of night one of your production DB cluster node goes down... Thats irritating.. So the solution is having a self healing cluster that will help us achieve high availability and automatic failover for the databases.


### MongoDB failover
MongoDB provides out of the box failover for their systems

- In primary-secondary architecture when primary node fails, secondary node takes its place.
- In primary-secondary-arbiter architecture setup when primary instance fails, arbiter node helps to elect secondary to become primary.


But what if the workload is too high and single instance cannot handle that load? or

What if you want to automate the process of adding another secondary node immediately when one of the nodes in a cluster fails?

Above mentioned architecture doesn't provide any facility to auto-recover your failed nodes.

### Self Healing Solution

Auto recovery of nodes allows your systems to be more stable and reliable. High availability of the cluster is a very vital thing. But then the question still remains how do we achieve this high availability.
You don't need to worry about that as I have already designed and implemented a solution for this problem and I thought it would be of great help for you too.

Let's go ahead and took a look at the implementation.
We are using Google Cloud Platform for the implementation of this solution. You can replicate similar setup on AWS or Azure.

Here is the system architecture for the same :

![New](https://s3.ap-south-1.amazonaws.com/cc-wiki-images/mongo.png)

#### ** Setup Instructions **

Here are the steps to implement automatic failover for Mongo on Google Cloud Platform infrastructure:


1. Create one managed instance group (MIG)  for mongo with two instances along with one data disk attached to these instances.
2. As shown in the diagram we will consume it as primary and secondary  node.
2. Create another managed instance group with single instance without data disk and make it as arbiter node.
3. Now for the very first time we have to setup mongo cluster manually or use [this](https://github.com/moreshital/ansible_playbooks/tree/master/mongo_cluster_setup) ansible role to set it up.
4. Once done with cluster setup, add healthcheck for your instance   group for checking service on TCP port 27017 (change this if you are not using default port)
2. If any instance within the instance group - I goes down then other instance will become primary which is default failover provided by mongo.
3. After that MIG will launch second instance and will perform following tasks automatically:
    - Attach one of the two free data disk to itself
    - Collect primary node's IP
    - Get it's HOSTNAME
    - Run mongo command on primary for following: 
         1. Iterate through number of members of cluster to check the state of unreachable instance
         2. Remove the entry of instance which is terminated ( having state=> not reachable/healthy)
         3. Add/Register itself to mongo cluster with HOSTNAME

8. All this can be handled through a startup script in GCP. 
9. Now add [this](https://github.com/moreshital/Mongo-Failover-Script/blob/master/mongo-multi-az.sh) startup script for MIG-I
10. In case if arbiter nodes fails, MIG - II will lauch new node and it will automatically get added to the cluster using startup script.
11. Add [this](https://github.com/moreshital/Mongo-Failover-Script/blob/master/mongo-arb.sh) startup script for MIG - II.

12. We have completed our setup of mongoDB cluster with self healing ability.


