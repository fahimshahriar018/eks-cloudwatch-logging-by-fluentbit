clusterName="devops-test-cluster"
nodeGroupName="controlplane-nodegroup"
region="us-west-2"
namespace="amazon-cloudwatch"

redColor='\e[1;31m'
greenColor='\e[1;32m'
noColor='\e[0m'

nodeRole=$(aws eks describe-nodegroup --cluster-name ${clusterName}  --nodegroup-name ${nodeGroupName}  --region ${region}  --query 'nodegroup.nodeRole' --output text | awk -F':role/' '{print $NF}')

# Attach  CloudWatchAgentServerPolicy to node role if not attached.
isPolicyExist=$(aws iam list-attached-role-policies --role-name $nodeRole | grep CloudWatchAgentServerPolicy )
if [[ $isPolicyExist == "" ]]
then
    echo -e "${redColor} CloudWatchAgentServerPolicy  is not attached to the role ${nodeRole} ${noColor}"
    aws iam attach-role-policy --role-name ${nodeRole} --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    if [[ $? -eq 0 ]]
    then 
        echo -e "${greenColor} policy is now attached to the Role ${noColor}"
    fi

else 
    echo -e "${greenColor} ${isPolicyExist}  ${noColor}"
fi

#Create amazon-cloudwatch namespace if not exit 
if [[ $(kubectl get ns) == *"${namespace}"* ]]
then 
    echo -e "${greenColor} ${namespace} namespace is already Existed. ${noColor}"
else
    echo -e "${greenColor} ------------------> Creating namespace ${namespace} ${noColor}"
    kubectl create ns ${namespace}
fi    




# Create a configmap named  cluster-info
configmap="fluent-bit-cluster-info"
if [[ $(kubectl -n ${namespace} get cm) == *"${configmap}"* ]]
then 
    echo -e "${redColor} ${configmap} configmap is already Existed. ${noColor}"
else
    echo -e "${greenColor} -------------> Creating configmap ${configmap} ${noColor}"
    [[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
    [[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
    kubectl create configmap ${configmap} \
    --from-literal=cluster.name=${clusterName} \
    --from-literal=http.server=${FluentBitHttpServer} \
    --from-literal=http.port=${FluentBitHttpPort} \
    --from-literal=read.head=${FluentBitReadFromHead} \
    --from-literal=read.tail=${FluentBitReadFromTail} \
    --from-literal=logs.region=${region} -n ${namespace}
    
fi 



# Download and deploy Fluent Bit daemonset to the cluster
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
if [[ $? -eq 0 ]]
then
    echo -e  "${greenColor} ############# fluentbit configured successfully ################# ${noColor}"
fi
# check pods
kubectl get pods -n ${namespace}


echo -e "${redColor} Check the list of log groups in the Region. You should see the following: \n
1. /aws/containerinsights/${clusterName}/application \n
2. /aws/containerinsights/${clusterName}/host \n
3. /aws/containerinsights/${clusterName}/dataplane ${noColor}"

