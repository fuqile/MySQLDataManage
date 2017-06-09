#!/bin/bash

set -e

#判断expect命令是否存在，不存在先安装
if ! command -v expect >/dev/null 2>&1; then
	sudo yum install -y expect
	#如果没执行成功就退出
	if [ ! "$?" -eq "0" ]; then 
		exit
	fi
fi

#聚宽mysql上的配置
jq_host="172.16.11.150"
jq_port="3308"
jq_username="jqreader"
jq_password="jqreader"
jq_database_name="finance"

#本地私有库mysql配置
local_host="localhost"
local_port="3306"
local_username="root"
local_password="admin"
local_database_name="finance"
#导出的数据文件
export_file="temp_export_data.sql"

#modTime条件，以时间为维度，导出导入该时间之后的数据
modTime="2017-02-03 00:00:00"


echo "Connect mysql to ${jq_host} ......"
expect << EOF
set timeout 72000
spawn sh -c "mysqldump --opt --skip-lock-tables --single-transaction --replace -t -h ${jq_host} -P ${jq_port} -u ${jq_username} -p ${jq_database_name} balance_sheet balance_sheet_day cash_flow_statement cash_flow_statement_acc cash_flow_statement_day financial_indicator financial_indicator_day income_statement income_statement_acc income_statement_day report_list stock_valuation -w \"modTime>='${modTime}'\" > ${export_file}"

expect {
	"password:" {
		send "${jq_password}\r"
		send_user "\nBegin to export data from ${jq_host} ......"
		exp_continue
	}
	-re "^.*\[error|ERROR|Error\].*$" {
		exit 1
	}
	eof {
		
	}
}
EOF
echo "Success to export data!"
echo "File saved in "`pwd`"/${export_file}"

#检查文件是否存在
if [ ! -e ${export_file} ]; then
	echo "Exception: import file not found!"
       	exit 1
#检查文件是否为空
elif [ ! -s ${export_file} ]; then
	echo "Exception: file is empty!"
	exit 1
fi

echo "Connect mysql to ${local_host} ......"
expect << EOF
set timeout 72000
spawn sh -c "mysql ${local_database_name} -h ${local_host} -P ${local_port} -u ${local_username} -p < ${export_file}"

expect {
	"password:" {
		send "${local_password}\r"
		send_user "\nBegin to import data from ${export_file} ......"
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
echo "Data imported success!"


