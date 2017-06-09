#!/bin/bash

#检查是否存在mysqldiff命令
if ! command -v mysqldiff >/dev/null 2>&1; then
	sudo yum install -y mysql-utilities
	#如果没执行成功就退出
	if [ ! "$?" -eq "0" ]; then 
		exit
	fi
fi

#主要数据源
server1_host="172.16.11.150"
server1_port="3308"
server1_username="jqreader"
server1_password="jqreader"

#需要根据差异进行更新的数据源
server2_host="localhost"
server2_port="3306"
server2_username="root"
server2_password="admin"

#需要比较的数据库
database="finance"
export_file="temp_diff_data.sql"


echo "Begin to compare data ......"
mysqldbcompare --server1=${server1_username}:${server1_password}@${server1_host}:${server1_port} --server2=${server2_username}:${server2_password}@${server2_host}:${server2_port} --changes-for=server2 --difftype=sql --skip-table-options --run-all-tests ${database} > ${export_file}

#判断是否执行成功
if [ ! "$?" -eq "0" ]; then 
	exit
else 
	echo "Success to compare data!"
	echo "Diff file saved in "`pwd`"/${export_file}"
fi

#检查文件是否存在
if [ ! -e ${export_file} ]; then
	echo "Exception: import file not found!"
       	exit 1
#检查文件是否为空
elif [ ! -s ${export_file} ]; then
	echo "Exception: file is empty!"
	exit 1
fi

echo "Connect mysql to ${server2_host} ......"
expect << EOF
set timeout 72000
spawn sh -c "mysql ${database} -h ${server2_host} -P ${server2_port} -u ${server2_username} -p < ${export_file}"

expect {
	"password:" {
		send "${server2_password}\r"
		send_user "\nBegin to update data from ${export_file} ......"
		exp_continue
	}
	-re "^.*\[error|ERROR|Error\].*$" {
		exit 1
	}
	eof {
		
	}
}
EOF
#导入完了删除临时文件
#rm -rf ${export_file}
echo "Data update success!"
