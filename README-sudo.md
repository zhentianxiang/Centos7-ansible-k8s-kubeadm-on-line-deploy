# 普通用户使用 ansible

### 1. 首先所有机器创建用户

```
[root@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main ~]# adduser deploy
[root@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main ~]# passwd deploy
[root@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main ~]# vim /etc/sudoers.d/deploy
[root@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main ~]# deploy ALL=(ALL) NOPASSWD: ALL
```

### 2. 配置主机器免密登录

```
[deploy@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main]$ cat iplist.txt 
11.0.1.31
11.0.1.32
11.0.1.33
11.0.1.34
11.0.1.35
[deploy@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main]$ for host in $(cat iplist.txt); do     sshpass -p '123456' ssh-copy-id -i /home/deploy/.ssh/id_rsa.pub -o StrictHostKeyChecking=no deploy@$host; done
```

### 2. 配置 ansible 普通用户

```
[deploy@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main]$ cat hosts.ini 
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

### 3. ansible 配置普通用户允许 sudo

```
[deploy@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main]$ more group_vars/all.yml 
ansible_become: true
ansible_become_method: sudo
```

### 4. 测试普通用户是否可以使用，运行时加上 --ask-become-pass（提示输入 sudo 密码）

```
[deploy@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main]$ ansible all -i hosts.ini -m ping --ask-become-pass
BECOME password: 
k8s-master1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
k8s-master2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
k8s-master3 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
k8s-node1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
k8s-node2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
etcd2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
etcd3 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
etcd1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "changed": false, 
    "ping": "pong"
}
```

### 5. 测试 ansible 是否可以提权，运行时加上 --ask-become-pass（提示输入 sudo 密码）

```
[deploy@localhost Centos7-ansible-k8s-kubeadm-on-line-deploy-main]$ ansible all -i hosts.ini -m shell -a whoami --ask-become-pass
BECOME password: 
k8s-master1 | CHANGED | rc=0 >>
root
k8s-master2 | CHANGED | rc=0 >>
root
k8s-node1 | CHANGED | rc=0 >>
root
k8s-node2 | CHANGED | rc=0 >>
root
k8s-master3 | CHANGED | rc=0 >>
root
etcd1 | CHANGED | rc=0 >>
root
etcd2 | CHANGED | rc=0 >>
root
etcd3 | CHANGED | rc=0 >>
root
```
