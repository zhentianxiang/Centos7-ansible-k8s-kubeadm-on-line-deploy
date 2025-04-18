## 一、基础环境配置

### 1. 安装 ansbile 和 sshpass

```sh
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ yum -y install ansible
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ vim /etc/ansible/ansible.cfg
 10 [defaults]
 11 ansible_shell_executable = /usr/bin/bash # 新增这个
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ssh-keygen -t rsa
```

### 2. 配置免密登陆

普通用户 sudo 配置请看项目根目录中的 README-sudo.md 文档

```shell
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ vim iplist.txt
11.0.1.31
11.0.1.32
11.0.1.33
11.0.1.34
11.0.1.35
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ for host in $(cat iplist.txt); do sshpass -p 'your_password' ssh-copy-id -o StrictHostKeyChecking=no 'deploy'@$host; done
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible -i hosts.ini all -m shell -a "whoami"
```

## 二、单 master 部署如下修改

### 1. 主机分组文件

```sh
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ vim hosts.ini 
[all]
k8s-master1 ansible_connection=local  ip=11.0.1.31
#k8s-master2 ansible_host=11.0.1.32 ip=11.0.1.32 ansible_port=22 ansible_user=deploy
#k8s-master3 ansible_host=11.0.1.33 ip=11.0.1.33 ansible_port=22 ansible_user=deploy
k8s-node1 ansible_host=11.0.1.34 ip=11.0.1.34 ansible_port=22 ansible_user=deploy
k8s-node2 ansible_host=11.0.1.35 ip=11.0.1.35 ansible_port=22 ansible_user=deploy
#etcd1 ansible_host=11.0.1.31 ip=11.0.1.31 ansible_port=22 ansible_user=deploy
#etcd2 ansible_host=11.0.1.32 ip=11.0.1.32 ansible_port=22 ansible_user=deploy
#etcd3 ansible_host=11.0.1.33 ip=11.0.1.33 ansible_port=22 ansible_user=deploy
# 对应更改all.yml 定义的master ip变量
[k8s]
k8s-master1
#k8s-master2
#k8s-master3
k8s-node1
k8s-node2

[master]
k8s-master1
#k8s-master2
#k8s-master3

[node]
k8s-node1
k8s-node2

[etcd]
#etcd1
#etcd2
#etcd3

# keepalived 高可用集群 + Nginx 负载均衡

# 如果不部署单 master ha 里面的可以注释掉了,避免产生警告信息
[ha]
#k8s-master1 ha_name=ha-master
#k8s-master2 ha_name=ha-backup
#k8s-master3 ha_name=ha-backup

#24小时token过期后添加node节点
[newnode]
[k8s:children]
master
node
newnode
```
### 2. 全局变量文件

> k8s_image_url:  集群初始化拉取的镜像前缀
>
> k8s_extra_ips:  kubrenetes master 节点信息(预留)，目的为了后期方便扩容 master 节点
>
> nic:  keepalived 调用的本地网卡的设备
>
> vip: keepalived 的虚拟 IP，如果部署单节点 master 把这个值写为 master 的 IP 地址即可
>
> lb_port: nginx 的负载均衡监听的端口，如果部署单节点 master 把这个值写为 6443 即可
>
> extra_ips:  etcd 集群的节点信息(预留)，目的为了后期方便扩容 etcd 节点
>
> calico_network: calico 调用本地网卡的设备

```sh
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ vim group_vars/all.yml
# 允许普通用户执行 sudo
ansible_become: true
ansible_become_method: sudo

tmp_dir: '/opt/k8s-install/join'

# 安装源配置
base_repo: "http://centos7-yum.linuxtian.com/CentOS-Base.repo"
epel_repo: "http://centos7-yum.linuxtian.com/CentOS-Base.repo"
docker_ce_repo: "https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo"

# docker 安装信息
docker_ce: 'docker-ce-20.10.9'
docker_ce_cli: 'docker-ce-cli-20.10.9'
containerd: 'containerd'
docker_data_dir: '/var/lib/docker'

# kubernetes 安装信息
ghproxy: 'https://ghfast.top/'
code_version: 'v1.23.0'
#containerd_data: '/var/lib/containerd'
#runc_version: 'v1.1.9'
#containerd_version: '1.7.25'
kube_version: '1.23.0'
k8s_version: 'v1.23.0'
kubelet_data_dir: '/var/lib/kubelet'
k8s_image_url: 'registry.cn-hangzhou.aliyuncs.com/google_containers'

# k8s master 节点预留 ip
k8s_extra_ips:
  - "11.0.1.131"
  - "11.0.1.132"
  - "11.0.1.133"
  - "11.0.1.134"
service_cidr: '10.96.0.0/16'
cluster_dns: '10.96.0.1'
pod_cidr: '192.18.0.0/16'
calico_network: '"interface=ens192"'

# keepalived 配置
nic: 'ens192'
Virtual_Router_ID: '51'
vip: '11.0.1.31'
api_vip_hosts: apiserver.cluster.local
notification_emails:
  - acassen@firewall.loc
  - failover@firewall.loc
  - sysadmin@firewall.loc
smtp_server: '127.0.0.1'
smtp_connect_timeout: '30'
auth_pass: 'kubernetes'

# 负载均衡端口
lb_port: '6443'

# ETCD 集群基本配置
etcd_data: '/var/lib/etcd-external'
etcd_version: 'v3.5.9'
etcd_conf: "/etc/etcd/"
etcd_ssl: '/etc/etcd/ssl'
etcd_cluster_token: "etcd-k8s-cluster"
# ETCD 集群初始状态 (new 或 existing)
etcd_initial_cluster_state: "new"
# 启动等待超时(秒)
etcd_startup_timeout: 60

# ETCD 集群备份
etcd_backup_dir: "/var/lib/etcd-backup"
etcd_backup_keep_days: 7
# etcd-server-csr host 信息预留
extra_ips:
  - "11.0.1.141"
  - "11.0.1.142"
  - "11.0.1.143"
  - "11.0.1.144"

# 性能调优参数
etcd_heartbeat_interval: 200
etcd_election_timeout: 2500
etcd_quota_backend_bytes: 5500000000
etcd_auto_compaction_retention: "1"
etcd_snapshot_count: 50000

# 安全配置
etcd_client_cert_auth: true
etcd_peer_client_cert_auth: true
etcd_auto_tls: false
etcd_peer_auto_tls: false
force_cert_gen: true
force_cert_sync: true

# 日志配置
etcd_log_level: "warn"
etcd_log_output: "stderr"

# 功能开关
etcd_enable_pprof: false
etcd_enable_v2: false
etcd_enable_localhost: true

# 第三方 yaml 路径
k8s_app: '/opt/k8s-install/app'                                                       # 创建了一个存放 yaml 文件的主目录
ingress_app: '/opt/k8s-install/app/ingress'                                           # ingress yaml 存放位置
ingres_label: 'ingress/type: nginx'                                                   # ingress 部署节点 label
openebs_app: '/opt/k8s-install/app/openebs_app'                                       # openebs_app yaml 存放位置
openebs_data: '"/data/openebs"'                                                       # openebs local pvc 数据存储目录
calico_app: '/opt/k8s-install/app/calico'                                             # calico yaml 存放位置

# 定义 Kubernetes 版本与 Calico 版本的映射相关文档: https://docs.tigera.io/calico/3.28/getting-started/kubernetes/requirements
k8s_calico_version_map:
  "1.28": "v3.28.0"
  "1.27": "v3.27.0"
  "1.26": "v3.26.0"
  "1.25": "v3.25.0"
  "1.24": "v3.24.0"
  "1.23": "v3.24.0"
  "1.22": "v3.24.0"

# 定义 Kubernetes 版本与 ingress-nginx 版本的映射
k8s_ingress_version_map:
  "1.29": "v1.10.0"
  "1.28": "v1.9.5"
  "1.27": "v1.9.5"
  "1.26": "v1.9.5"
  "1.25": "v1.5.1"
  "1.24": "v1.5.1"
  "1.23": "v1.5.1"
  "1.22": "v1.5.1"
default_calico_version: "v3.25.0"
default_ingress_version: "v1.5.1"

# 自定义 hosts 解析,ansible 会帮我们自动添加
custom_hosts:
  registry.example.com: 127.0.0.1
```

### 3. 执行部署

```sh
# 不是必须的，根据实际情况来判断自己是否要升级内核
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible-playbook -i hosts.ini install_kernel.yml
```

```shell
# 使用单点 master 不包含 etcd 专用的 hosts 文件
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ \cp roles/init/templates/no-etcd-hosts.j2 roles/init/templates/hosts.j2
```

```sh
# 使用 single 文件部署
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible-playbook -i hosts.ini single-master-deploy.yml
```

## 三、多 master 集群方式部署

### 1. 主机分组文件

```sh
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ vim hosts.ini
[all]
k8s-master1 ansible_connection=local  ip=11.0.1.31
k8s-master2 ansible_host=11.0.1.32 ip=11.0.1.32 ansible_port=22 ansible_user=deploy
k8s-master3 ansible_host=11.0.1.33 ip=11.0.1.33 ansible_port=22 ansible_user=deploy
k8s-node1 ansible_host=11.0.1.34 ip=11.0.1.34 ansible_port=22 ansible_user=deploy
k8s-node2 ansible_host=11.0.1.35 ip=11.0.1.35 ansible_port=22 ansible_user=deploy
etcd1 ansible_host=11.0.1.31 ip=11.0.1.31 ansible_port=22 ansible_user=deploy
etcd2 ansible_host=11.0.1.32 ip=11.0.1.32 ansible_port=22 ansible_user=deploy
etcd3 ansible_host=11.0.1.33 ip=11.0.1.33 ansible_port=22 ansible_user=deploy
# 对应更改all.yml 定义的master ip变量
[k8s]
k8s-master1
k8s-master2
k8s-master3
k8s-node1
k8s-node2

[master]
k8s-master1
k8s-master2
k8s-master3

[node]
k8s-node1
k8s-node2

[etcd]
etcd1
etcd2
etcd3

# keepalived 高可用集群 + Nginx 负载均衡

# 如果不部署单 master ha 里面的可以注释掉了,避免产生警告信息
[ha]
k8s-master1 ha_name=ha-master
k8s-master2 ha_name=ha-backup
k8s-master3 ha_name=ha-backup

#24小时token过期后添加node节点
[newnode]
[k8s:children]
master
node
newnode
```

### 2. 全局变量文件

> k8s_image_url:  集群初始化拉取的镜像前缀
>
> k8s_extra_ips:  kubrenetes master 节点信息(预留)，目的为了后期方便扩容 master 节点
>
> nic:  keepalived 调用的本地网卡的设备
>
> vip: keepalived 的虚拟 IP，如果部署单节点 master 把这个值写为 master 的 IP 地址即可
>
> lb_port: nginx 的负载均衡监听的端口，如果部署单节点 master 把这个值写为 6443 即可
>
> extra_ips:  etcd 集群的节点信息(预留)，目的为了后期方便扩容 etcd 节点
>
> calico_network: calico 调用本地网卡的设备

```sh
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ vim group_vars/all.yml
# 允许普通用户执行 sudo
# 允许普通用户执行 sudo
ansible_become: true
ansible_become_method: sudo

tmp_dir: '/opt/k8s-install/join'

# 安装源配置
base_repo: "http://centos7-yum.linuxtian.com/CentOS-Base.repo"
epel_repo: "http://centos7-yum.linuxtian.com/CentOS-Base.repo"
docker_ce_repo: "https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo"

# docker 安装信息
docker_ce: 'docker-ce-20.10.9'
docker_ce_cli: 'docker-ce-cli-20.10.9'
containerd: 'containerd'
docker_data_dir: '/var/lib/docker'

# kubernetes 安装信息
ghproxy: 'https://ghfast.top/'
code_version: 'v1.23.0'
#containerd_data: '/var/lib/containerd'
#runc_version: 'v1.1.9'
#containerd_version: '1.7.25'
kube_version: '1.23.0'
k8s_version: 'v1.23.0'
kubelet_data_dir: '/var/lib/kubelet'
k8s_image_url: 'registry.cn-hangzhou.aliyuncs.com/google_containers'

# k8s master 节点预留 ip
k8s_extra_ips:
  - "11.0.1.131"
  - "11.0.1.132"
  - "11.0.1.133"
  - "11.0.1.134"
service_cidr: '10.96.0.0/16'
cluster_dns: '10.96.0.1'
pod_cidr: '192.18.0.0/16'
calico_network: '"interface=ens192"'

# keepalived 配置
nic: 'ens192'
Virtual_Router_ID: '51'
vip: '11.0.1.30'
api_vip_hosts: apiserver.cluster.local
notification_emails:
  - acassen@firewall.loc
  - failover@firewall.loc
  - sysadmin@firewall.loc
smtp_server: '127.0.0.1'
smtp_connect_timeout: '30'
auth_pass: 'kubernetes'

# 负载均衡端口
lb_port: '16443'

# ETCD 集群基本配置
etcd_data: '/var/lib/etcd-external'
etcd_version: 'v3.5.9'
etcd_conf: "/etc/etcd/"
etcd_ssl: '/etc/etcd/ssl'
etcd_cluster_token: "etcd-k8s-cluster"
# ETCD 集群初始状态 (new 或 existing)
etcd_initial_cluster_state: "new"
# 启动等待超时(秒)
etcd_startup_timeout: 60

# ETCD 集群备份
etcd_backup_dir: "/var/lib/etcd-backup"
etcd_backup_keep_days: 7
# etcd-server-csr host 信息预留
extra_ips:
  - "11.0.1.141"
  - "11.0.1.142"
  - "11.0.1.143"
  - "11.0.1.144"

# 性能调优参数
etcd_heartbeat_interval: 200
etcd_election_timeout: 2500
etcd_quota_backend_bytes: 5500000000
etcd_auto_compaction_retention: "1"
etcd_snapshot_count: 50000

# 安全配置
etcd_client_cert_auth: true
etcd_peer_client_cert_auth: true
etcd_auto_tls: false
etcd_peer_auto_tls: false
force_cert_gen: true
force_cert_sync: true

# 日志配置
etcd_log_level: "warn"
etcd_log_output: "stderr"

# 功能开关
etcd_enable_pprof: false
etcd_enable_v2: false
etcd_enable_localhost: true

# 第三方 yaml 路径
k8s_app: '/opt/k8s-install/app'                                                       # 创建了一个存放 yaml 文件的主目录
ingress_app: '/opt/k8s-install/app/ingress'                                           # ingress yaml 存放位置
ingres_label: 'ingress/type: nginx'                                                   # ingress 部署节点 label
openebs_app: '/opt/k8s-install/app/openebs_app'                                       # openebs_app yaml 存放位置
openebs_data: '"/data/openebs"'                                                       # openebs local pvc 数据存储目录
calico_app: '/opt/k8s-install/app/calico'                                             # calico yaml 存放位置

# 定义 Kubernetes 版本与 Calico 版本的映射相关文档: https://docs.tigera.io/calico/3.28/getting-started/kubernetes/requirements
k8s_calico_version_map:
  "1.28": "v3.28.0"
  "1.27": "v3.27.0"
  "1.26": "v3.26.0"
  "1.25": "v3.25.0"
  "1.24": "v3.24.0"
  "1.23": "v3.24.0"
  "1.22": "v3.24.0"

# 定义 Kubernetes 版本与 ingress-nginx 版本的映射
k8s_ingress_version_map:
  "1.29": "v1.10.0"
  "1.28": "v1.9.5"
  "1.27": "v1.9.5"
  "1.26": "v1.9.5"
  "1.25": "v1.5.1"
  "1.24": "v1.5.1"
  "1.23": "v1.5.1"
  "1.22": "v1.5.1"
default_calico_version: "v3.25.0"
default_ingress_version: "v1.5.1"

# 自定义 hosts 解析,ansible 会帮我们自动添加
custom_hosts:
  registry.example.com: 127.0.0.1
```

### 3. 执行部署

```sh
# 不是必须的，根据实际情况来判断自己是否要升级内核
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible-playbook -i hosts.ini install_kernel.yml
```

```shell
# 使用集群 master 包含 etcd 专用的 hosts 文件
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ \cp roles/init/templates/yes-etcd-hosts.j2 roles/init/templates/hosts.j2
```

```sh
# 使用 multi 文件部署
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible-playbook -i multi-master-ha-deploy.yml
```

## 三、验证集群

### 1. 查看 etcd 集群状态

```shell
# 其实还是当前机器，因为我的 etcd 和 master 公用的同一台机器
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ssh etcd1 
Last login: Mon Apr 14 13:20:03 2025
[deploy@k8s-master1 ~]$ 
```

```shell
# etcd 节点基本信息
[deploy@k8s-master1 ~]$ sudo etcdctl --cacert=/etc/etcd/ssl/etcd-ca.pem --cert=/etc/etcd/ssl/etcd-server.pem --key=/etc/etcd/ssl/etcd-server-key.pem --endpoints="https://etcd1:2379,https://etcd2:2379,https://etcd3:2379" member list -w table
+------------------+---------+-------+------------------------+------------------------+------------+
|        ID        | STATUS  | NAME  |       PEER ADDRS       |      CLIENT ADDRS      | IS LEARNER |
+------------------+---------+-------+------------------------+------------------------+------------+
| 19057a4144bcd8c4 | started | etcd2 | https://11.0.1.32:2380 | https://11.0.1.32:2379 |      false |
| 7467e635c43f67f4 | started | etcd1 | https://11.0.1.31:2380 | https://11.0.1.31:2379 |      false |
| 8eb8e095642da063 | started | etcd3 | https://11.0.1.33:2380 | https://11.0.1.33:2379 |      false |
+------------------+---------+-------+------------------------+------------------------+------------+

# etcd 集群各节点的健康状态
[deploy@k8s-master1 ~]$ sudo etcdctl --cacert=/etc/etcd/ssl/etcd-ca.pem --cert=/etc/etcd/ssl/etcd-server.pem --key=/etc/etcd/ssl/etcd-server-key.pem --endpoints="https://etcd1:2379,https://etcd2:2379,https://etcd3:2379" endpoint health --write-out=table
+--------------------+--------+-------------+-------+
|      ENDPOINT      | HEALTH |    TOOK     | ERROR |
+--------------------+--------+-------------+-------+
| https://etcd1:2379 |   true |  11.55301ms |       |
| https://etcd3:2379 |   true | 10.722732ms |       |
| https://etcd2:2379 |   true |  8.544486ms |       |
+--------------------+--------+-------------+-------+

# 查看 etcd 集群各节点的详细状态信息 的命令，比 endpoint health 提供更丰富的数据
[deploy@k8s-master1 ~]$ sudo etcdctl --cacert=/etc/etcd/ssl/etcd-ca.pem --cert=/etc/etcd/ssl/etcd-server.pem --key=/etc/etcd/ssl/etcd-server-key.pem --endpoints="https://etcd1:2379,https://etcd2:2379,https://etcd3:2379" endpoint status -w table
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|      ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://etcd1:2379 | 7467e635c43f67f4 |   3.5.9 |  9.3 MB |     false |      false |         4 |     172130 |             172130 |        |
| https://etcd2:2379 | 19057a4144bcd8c4 |   3.5.9 |  9.3 MB |      true |      false |         4 |     172130 |             172130 |        |
| https://etcd3:2379 | 8eb8e095642da063 |   3.5.9 |  9.4 MB |     false |      false |         4 |     172130 |             172130 |        |
+--------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+

# 查看 ETCD 备份情况
[deploy@k8s-master1 ~]$ sudo systemctl status etcd-backup.timer
[deploy@k8s-master1 ~]$ sudo systemctl status etcd-backup.service

[deploy@k8s-master1 ~]$ sudo ls -lh /var/lib/etcd-backup/
[deploy@k8s-master1 ~]$ sudo ls -lh /var/lib/etcd-backup/ |tail -n 1
-rw------- 1 etcd etcd 8.9M Apr 14 13:00 etcd-snapshot-20250414-130000.db

[deploy@k8s-master1 ~]$ sudo ETCDCTL_API=3 etcdctl --cacert=/etc/etcd/ssl/etcd-ca.pem \
  --cert=/etc/etcd/ssl/etcd-server.pem --key=/etc/etcd/ssl/etcd-server-key.pem \
  --endpoints=https://etcd1:2379 snapshot status /var/lib/etcd-backup/etcd-snapshot-20250414-130000.db

[deploy@k8s-master1 ~]$ logout
Connection to etcd1 closed.
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ 
```

### 2. 检查 k8s 集群状态

```shell
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ sudo kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE   ERROR
scheduler            Healthy   ok        
controller-manager   Healthy   ok        
etcd-0               Healthy   ok

[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ sudo kubectl get node -o wide
NAME          STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
k8s-master1   Ready    control-plane   14h   v1.23.0   11.0.1.31     <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   containerd://1.7.25
k8s-master2   Ready    control-plane   14h   v1.23.0   11.0.1.32     <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   containerd://1.7.25
k8s-master3   Ready    control-plane   14h   v1.23.0   11.0.1.33     <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   containerd://1.7.25
k8s-node1     Ready    <none>          14h   v1.23.0   11.0.1.34     <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   containerd://1.7.25
k8s-node2     Ready    <none>          14h   v1.23.0   11.0.1.35     <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   containerd://1.7.25

[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ sudo kubectl label node {k8s-node1,k8s-node2} ingress/type=nginx
node/k8s-node1 labeled
node/k8s-node2 labeled
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ sudo kubectl get pods -A
NAMESPACE       NAME                                            READY   STATUS      RESTARTS      AGE
ingress-nginx   ingress-nginx-admission-create-dd8z8            0/1     Completed   1             14h
ingress-nginx   ingress-nginx-admission-patch-mml7t             0/1     Completed   2             14h
ingress-nginx   ingress-nginx-controller-2qjpn                  1/1     Running     0             6m14s
ingress-nginx   ingress-nginx-controller-lwz4w                  1/1     Running     0             5m52s
kube-system     calico-kube-controllers-5678d86b78-zfvz8        1/1     Running     0             6m7s
kube-system     calico-node-22fkm                               1/1     Running     0             14h
kube-system     calico-node-8kb75                               1/1     Running     0             14h
kube-system     calico-node-g85rv                               1/1     Running     0             6m22s
kube-system     calico-node-mr5ls                               1/1     Running     0             6m22s
kube-system     calico-node-tgmgq                               1/1     Running     0             14h
kube-system     coredns-f8dcdd6b5-b4vgf                         1/1     Running     0             14h
kube-system     coredns-f8dcdd6b5-wbl8s                         1/1     Running     0             14h
kube-system     kube-apiserver-k8s-master1                      1/1     Running     4             14h
kube-system     kube-apiserver-k8s-master2                      1/1     Running     4             14h
kube-system     kube-apiserver-k8s-master3                      1/1     Running     2             14h
kube-system     kube-controller-manager-k8s-master1             1/1     Running     5             14h
kube-system     kube-controller-manager-k8s-master2             1/1     Running     4             14h
kube-system     kube-controller-manager-k8s-master3             1/1     Running     2             14h
kube-system     kube-proxy-4qf79                                1/1     Running     0             14h
kube-system     kube-proxy-btp8t                                1/1     Running     0             14h
kube-system     kube-proxy-w6zzp                                1/1     Running     0             14h
kube-system     kube-proxy-zclj7                                1/1     Running     0             14h
kube-system     kube-proxy-zv7z8                                1/1     Running     0             14h
kube-system     kube-scheduler-k8s-master1                      1/1     Running     5             14h
kube-system     kube-scheduler-k8s-master2                      1/1     Running     4             14h
kube-system     kube-scheduler-k8s-master3                      1/1     Running     2             14h
openebs         openebs-localpv-provisioner-6787b599b9-c7cxd    1/1     Running     0             14h
openebs         openebs-ndm-cluster-exporter-7bfd5746f4-jkcnw   1/1     Running     0             14h
openebs         openebs-ndm-j7p9n                               1/1     Running     0             14h
openebs         openebs-ndm-mclk2                               1/1     Running     0             14h
openebs         openebs-ndm-node-exporter-845g7                 1/1     Running     0             14h
openebs         openebs-ndm-node-exporter-jf9n5                 1/1     Running     1 (14h ago)   14h
openebs         openebs-ndm-operator-845b8858db-57qkj           1/1     Running     0             14h
```

```shell
# 如果pod一直 pending 或者 node 无法 ready，则重启 containerd 属于 BUG
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible -i hosts.ini k8s -m shell -a "systemctl restart containerd"
```

```shell
# 创建服务
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ sudo kubectl create deployment nginx --image=harbor.meta42.indc.vnet.com/library/nginx:latest --replicas=4

[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ sudo kubectl expose deployment nginx --port=80 --target-port=80 --type=NodePort
```

## 四、配置 ingress 7 层代理

### 1. ha 节点 (master 节点) 修改配置

```shell
# 3 台 master 机器相同配置
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ sudo vim /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

# HTTP负载均衡配置
http {

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                     'Status: $status BodyBytesSent: $body_bytes_sent '
                     'Referer: "$http_referer" '
                     'UserAgent: "$http_user_agent" '
                     'XForwardedFor: "$http_x_forwarded_for" '
                     'Upgrade: $http_upgrade Connection: $http_connection '
                     'Host: $http_host '
                     'CacheStatus: $upstream_cache_status '
                     'RequestTime: $request_time';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    include /etc/nginx/conf.d/*.conf;
    default_type application/octet-stream;

    client_max_body_size 102400m;

    # HTTP Ingress-Nginx负载均衡
    upstream ingress-nginx-http {
        server 11.0.1.33:80;  # 选择 ingress 所在的节点
        server 11.0.1.34:80;  # 选择 ingress 所在的节点
    }

    # HTTPS Ingress-Nginx负载均衡
    upstream ingress-nginx-https {
        server 11.0.1.33:443;  # 选择 ingress 所在的节点
        server 11.0.1.34:443;  # 选择 ingress 所在的节点
    }

    # HTTP负载均衡
    server {
        listen 80;

        location / {
            proxy_pass http://ingress-nginx-http;  # 指定 HTTP 上游
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    # HTTPS负载均衡
    server {
        listen 443 ssl;
        ssl_certificate /etc/nginx/cret/nginx/*.linuxtian.com.crt;
        ssl_certificate_key /etc/nginx/cret/nginx/*.linuxtian.com.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384';
        ssl_prefer_server_ciphers on;


        location / {
            proxy_pass https://ingress-nginx-https;  # 指定 HTTPS 上游
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```
## 五、其他相关配置

### 1. 调整 kube 启动参数 (可选修改)

```sh
# 请手动执行以下命令来修改 kube 自定义配置：
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ sed -i "/image:/i\    - --feature-gates=RemoveSelfLink=false" /etc/kubernetes/manifests/kube-apiserver.yaml # 每台 master 都执行
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ sed -i "s/bind-address=127.0.0.1/bind-address=0.0.0.0/g" /etc/kubernetes/manifests/kube-controller-manager.yaml # 每台 master 都执行
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ kubectl get cm -n kube-system kube-proxy -o yaml | sed "s/metricsBindAddress: \"\"/metricsBindAddress: \"0.0.0.0\"/g" | kubectl replace -f -
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ kubectl rollout restart daemonset -n kube-system kube-proxy
```

### 2. 解决 node 节点报错

`Sep 14 00:59:22 k8s-node1 kubelet[1611]: E0914 00:59:22.040084    1611 file_linux.go:61] "Unable to read config path" err="path does not exist, ignoring" path="/etc/kubernetes/manifests"`

```sh
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible -i hosts.ini node -m shell -a "mkdir -pv /etc/kubernetes/manifests"
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible -i hosts.ini node -m shell -a "systemctl restart kubelet"
```

## 六、k8s 节点平滑扩容

### 1. ip 列表新增机器

```shell
# 新增机器的 IP 地址
[root@k8s-master1 Centos7-ansible-k8s-kubeadm-on-line-deploy-main]# cat iplist.txt 
11.0.1.31
11.0.1.32
11.0.1.33
11.0.1.34
11.0.1.35
11.0.1.36 # 新增
11.0.1.37 # 新增
11.0.1.38 # 新增
```

### 2. 配置免密登陆

```shell
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ for host in $(cat iplist.txt); do sshpass -p 'your_password' ssh-copy-id -o StrictHostKeyChecking=no 'deploy'@$host; done
```

### 3. 主机分组新增机器

```shell
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ vim hosts.ini
# 全部分组下面新增3个
[all] 
k8s-node-3 ansible_host=11.0.1.36 ip=11.0.1.36 ansible_port=22 ansible_user=deploy
k8s-node-4 ansible_host=11.0.1.37 ip=11.0.1.37 ansible_port=22 ansible_user=deploy
k8s-node-5 ansible_host=11.0.1.38 ip=11.0.1.38 ansible_port=22 ansible_user=deploy

# k8s 分组下面新增3个
[k8s]
k8s-node3
k8s-node4
k8s-node5

# newnode 分组里面也新增3个
[newnode]
k8s-node-3
k8s-node-4
k8s-node-5
```

### 4. 测试是否能用

```sh
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible -i hosts.ini newnode -m shell -a "whoami"
```

### 5. 升级内核 (可选操作)

```sh
# --limit 指定 newnode 分组,默认文件里面应该是 k8s 分组，所以我们只希望升级新添加机器的内核
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible-playbook -i hosts.ini --limit newnode install_kernel.yml
```

### 6. 执行操作

```sh
# 指向 add 文件
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible-playbook -i hosts.ini add-node.yml
```

### 7. 解决 node 节点报错

`Sep 14 00:59:22 k8s-node1 kubelet[1611]: E0914 00:59:22.040084    1611 file_linux.go:61] "Unable to read config path" err="path does not exist, ignoring" path="/etc/kubernetes/manifests"`

```sh
# 选择 newnode 分组,因为这个里面是新增的机器
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible -i hosts.ini newnode -m shell -a "mkdir -pv /etc/kubernetes/manifests"
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible -i hosts.ini newnode -m shell -a "systemctl restart kubelet"
```

## 七、其他操作

### 1. 配置 harbor 证书

```sh
# 拷贝 harbor 证书文件，当然 ansbile 中是没有的，需要后期自己部署 harbor，只是为了使用 ansible 统一集群配置
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible -i hosts.ini k8s -m copy -a "src=/etc/containerd/certs.d/ dest=/etc/containerd/certs.d/ mode=0755" --become
```

### 2. 安装低版本 k8s 使用 docker 不使用 containerd

```shell
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ vim multi-master-ha-deploy.yml
- name: 3.部署Docker  # 把原本的修改为 docker
  gather_facts: true
  hosts: k8s
  roles:
    - docker
  tags: docker
```

```shell
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ vim group_vars/all.yml
code_version: 'v1.23.0'   # 修改为 1.23.0
kube_version: '1.23.0'    # 修改为 1.23.0
k8s_version: 'v1.23.0'    # 修改为 1.23.0
```

```shell
# 使用对应的版本的 kubeadm
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ \cp roles/master/files/kubeadm-1.23.0  roles/master/files/kubeadm
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ \cp roles/joinmaster/files/kubeadm-1.23.0  roles/master/files/kubeadm
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ \cp roles/single-master/files/kubeadm-1.23.0  roles/master/files/kubeadm
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ \cp roles/node/files/kubeadm-1.23.0  roles/master/files/kubeadm
```

```shell

# 执行部署
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible-playbook -i hosts.ini multi-master-ha-deploy.yml
```

## 八、卸载删除集群

```sh
[deploy@k8s-master1 Centos7-ansible-k8s-containerd-20250413]$ ansible-playbook -i hosts.ini remove-k8s.yml
```
