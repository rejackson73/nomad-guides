#Nomad Feature Demo Setup and Script

This exercise demonstrates the quota, namespace, and preemption functionality available in the Enterprise Nomad product.  The infrastructure utilizes the SockShop demonstration provided and maintained by Weaveworks, and is built and operated using Terraform, Vault, and Consul. However, the main focus of the demonstration is on the functionality of Nomad.  All code and configuration is maintained in Github, however, SSH to the servers (and optionally HTTP access) is required.  

It is in the best interest of ALL Involved to ensure the environment is setup properly before actually performing the demo.  At this time, however, the workspace must be destroyed completed as part of the ‘reset’ procedure.  

##Pre-requisites:
1.	Access to Terraform Cloud, Github (need exact project)
2.	Access to AWS US-East-1 Region
3.	AWS Keypair to use for the servers
4.	Vault login token for demo vault server (is http://kubernetes-vault-elb-1163802512.us-east-1.elb.amazonaws.com:8200)
5.	Token for Nomad to Vault:  vault token create -policy nomad-server -ttl=720h | sed -e '1,2d' | sed -e '2,6d' | sed 's/ //g' | sed 's/token//' When running that command, be sure to include the final single quote. You will need to add the token to your workspace variables later.

Setting up the environment:

It is recommended to fork the existing Github repository in case changes are required.  This repository will also be connected to Terraform for system provisioning.

Within Terraform, perform the following actions:
-	Create your own organization. This will be used for your workspace
-	Within your organization, go to ‘Settings’ and ‘VCS Providers’ to setup your connection to Github using OAuth.
-	Create your own workspace
    * Configure a workspace Name
    * Select Github as the source and configure the proper repository
    * Within your workspace, select Settings -> General. Select Terraform version 0.11.14, select “Auto Apply,” and configure the working directory to be “application-deployment/microservices/aws”
    * Configure the following variables

Terraform Variables | Values 
---------|----------
 key_name | <name for AWS Keypair in Pre-requisites step 2> 
 private_key_data |<contents of keypair including “-----BEGIN RSA PRIVATE KEY-----” and “-----END RSA PRIVATE KEY-----“> 
 name_tag_prefix |   
 cluster_tag_value |  
 owner | <your name/username>
 ttl | 774
 vault_url | http://kubernetes-vault-elb-1163802512.us-east-1.elb.amazonaws.com:8200
 client_count | 3
 server_count | 3
 token_for_nomad | <token created in pre-requisites step 5>
 ami | ami-036cc6a2552adfa12


Environment Variables | Values 
---------|----------
VAULT_TOKEN | <personal vault token created in pre-requisites step 4>

Demonstration Flow

Review the Nomad Demo presentation, being sure to hit the following points:
-	How the Sockshop demo works at a high level
-	The fact that Nomad is managing both Docker Microservices and a Java app
-	The demonstration includes all four of Hashicorp’s main products, but we’re focusing on Nomad
-	Solution can be applied to multiple regions or even multiple clouds/hybrid clouds for better resource management.

Demo walk through
-	Show the Workspace Settings, ‘General’ and ‘Version Control.’’  Explain the connection to Github, the Version Selection, Auto/Manual apply.
-	Show the Workspace Variables, explaining what each key means (table above should help).  Call out how certain variables are ‘sensitive’ and thereby hidden to the user
-	Kick off the Terraform Plan

While the Terraform Plan is running
-	Access Github and show the main.tf.  Point out the multiple providers (Vault, Nomad, AWS), the NomadConsul Module, and the ‘nomad’ and ‘remote exec’ provisioners
-	Briefly show the nomadconsul module to explain that this was custom crafted to create all of the security groups being created for communication.  Towards the bottom find the EC2 instances and explain how the variables configured in Terraform are applied here.  
-	Show the output.tf file, explaining that parameters created as part of the deployment are displayed here for the user.
Hopefully by now the Terraform deployment has finished. Click on the “Apply Finished‘’ section to show the output of the plan.  

Copy the ‘Nomad UI’ line and paste that into your browser.  Note that there are two ‘jobs’ for the Sock Shop, one sockshop and one sockshopui.  Take a minute to walk through the sockshop job in the UI, pointing out the resources used, allocations, etc.

Time to switch to CLI.  Ssh using your preconfigured PEM key to one of the master nodes.  You can use the same IP that was used for the UI.

`ssh -i <pem key> ubuntu@<master_node>`

Show the nomad jobs running, just like in the UI:
`nomad job status`

Show the details of the sockshop application:

`nomad job status sockshop`

Find the node that is running the backoffice task.  This is the node that has multiple task drivers.  Look at the node details.

`nomad node status <node_id>`

You can see the resources utilized, but most importantly look for the Driver Status.  Point out that Nomad is using more than Docker containers.

Next talk about quota allocations for resources, and how quotas can be assigned to jobs, regions, or namespaces. 

`nomad quota status default`

Explain that this is a default quota applied.  You can see the total resources for this default quota, both CPU and Memory.  

Next, explain that what we would like is to have log monitoring setup on this machine.  So I’ve been tasked with getting a FluentD container running in the cluster.  I found a nomad job spec for a fluentd container online, and the file is already here (monitoring.nomad).

Execute:
`nomad job plan monitoring.nomad`

Note that we get a warning on the allocation.  Grr…not enough resources on our quota limit.  Hey, I heard about this thing called Namespaces where you can restrict access and quotas for each namespace.  So, I’m going to create a new namespace called ‘monitor’ and try deploying my job in that namespace.

`nomad namespace apply monitor`

Edit the monitoring.nomad file to uncomment the namespace line, and rerun the plan command.  This time it is successful, so execute the plan using the output string:

`nomad job run -check-index <number> monitoring.nomad	`

Show the running jobs again.  Note that you only see the sockhop and sockshop jobs still.  Ah but the monitoring job is running in a new ‘monitor’ namespace, so execute:

`nomad job status -namespace monitor`

So now I was able to get around the resource limits on the default namespace, by creating my own, editing my job file, and deploying my job to the new namespace.  Of course in production you would have Sentinel policies to restrict and manage that, but that’s another demo.

Oh now my manager is telling me that we are getting more activity on our website, and people are using more shopping carts, so we need to increase the number of shopping cart tasks.  Edit the sockshop.nomad and search for the ‘cart’ section.  Increase the count from 1 to 3.  Save the file, explaining that you’re just configuring the job to run more ‘carts.’  Plan the nomad job.

`nomad job plan sockshop.nomad`

The output of this job SHOULD including a note on preemption, similar to below:

`Preemptions:`

`Alloc ID                              Job ID      Task Group`

`e87e0d4a-b3c4-6a25-9c2b-ea8c1f2e599e  monitoring foundation Job Modify Index: 18`

Explain that this is a warning that in order to run our changes, the system will be preempting the noted allocation ID.  Hey, look what job that refers to…the monitoring job we ran before. Once again, show the running jobs for both the default and monitor namespace.

`nomad job status`

`nomad job status -namespace monitor`

Note that the priorities are different among jobs.  The Sockshop job has a priority of 50, whilst the monitoring job has a priority of 10.  This is what tells Nomad that it can steal from monitoring to pay sockshop.

Run the new sockshop job using the ‘nomad job run’ command returned from the plan.  Once that is run, check on the status of the monitoring job.

`nomad job status -namespace monitor`

You should see that the status is now in ‘pending’ state.  Although we were able to avoid the quota using another namespace, we can’t avoid the overall resource restriction on the three servers.  We could then increase the priority of the monitoring job and rerun it, but I think we’ve demonstrated what we set out to.  

One last task.  We know that we can’t run all of the jobs due to the overall resources, so let’s increase the number of clients we have.  Return to the Terraform UI, to the Variables page for your workspace.  Increase your ‘client_count’ variable from 3 to 4, and queue the plan. You can probably guess what is going to happen.

While that node is getting deployed, return to the Nomad UI, and under ‘Workload’ select ‘monitor’.  From here you can also see that the monitoring job is in pending state.  If you select the ‘monitoring’ job, you can show the placement failure due to lack of resources.

Return to the ‘Clients’ section of the UI, and now we make small talk while we wait for the fourth node to show up.  Once the node shows up, point out how the allocations are adjusted.  Then return to the monitoring job, and you can see that it is running again.

So we did some things in this demonstration that you would want to protect against using Sentinel, but hopefully we were able to demonstrate the flexibility and functionality of Nomad.  Now imagine this functionality across multi and hybrid cloud infrastructures, running all types of jobs!

