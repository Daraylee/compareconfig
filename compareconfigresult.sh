#查找本目录下所有.java文件中含有“@value”的键值对，并将键的部分保存在localconfig.txt中
find . -name "*.java"  | xargs grep "@Value" | awk -F '@Value' '{print $2}' | awk -F '{' '{print $2}' | awk -F '}' '{print $1}' | awk -F ':' '{print $1}' > localconfig.txt

find . -name "*.java"  | xargs grep "@Value" | awk -F '@Value' '{print $2}' |awk -F '{' '{if($2!=""&& $2!="$") print $2}' | awk -F '}' '{if(index($1,":")==0)print $1}'>unsetdefaultvalue.txt

find . -name "*.java"  | xargs grep "@Value" | awk -F '@Value' '{print $2}' | awk -F '{' '{if($2=="")print $1;else if($2=="$")print $0}' > checkunnormal.txt

#将config文件配置转换成jason格式，并保存在remoteconfig.txt
curl http://localhost:8082/actuator/env | python -m json.tool > remoteconfig.txt

#将remoteconfig.txt中jason格式转换成键值对的形式，并保存在remoteconfigformat.txt
cat remoteconfig.txt | awk '{if(index($0,"{")) printf("%s",$0);else if(index($0,"}")) printf("%s\n",$0);else printf("%s",$0);}' > remoteconfiginit.txt

cat remoteconfiginit.txt | awk -F '{' '{print $1,$2}' | awk -F '}' '{print $1}' | awk -F '"value":' '{print $1,$2}' | awk -F '":' '{print $1,$2}' | awk -F '"' '{print $2,$3}' | awk -F ' ' '{print $1,$2}' > remoteconfigformat.txt

#将localconfig.txt与remoteconfigformat.txt进行对比，并返回对比结果，如果全部匹配则返回success，没有则返回具体不匹配的数据

unconfigcount=0
#cat localconfig.txt | while read line
while read line
do
  if grep -q "$line" remoteconfigformat.txt
    then
      continue
  else      
      echo "$line">>checkunconfig.txt
      let unconfigcount=$unconfigcount+1
  fi
done <  localconfig.txt 
if [ "$unconfigcount" -eq "0" ]
  then	
   echo "SUCCESS"
fi
rm -f ./localconfig.txt ./remoteconfiginit.txt
unsetdefaultvalue=`cat unsetdefaultvalue.txt | awk '{if($0!="")print $0}'`
if [ "${unsetdefaultvalue}"x != ""x ];then
  echo "---------------检查出@Value注解没有设置默认值的地方---------------"
  cat unsetdefaultvalue.txt | sort -u
fi
checkunnormal=`cat checkunnormal.txt | awk '{if($0!="")print $0}'`;
if [ "${checkunnormal}"x != ""x ];then
  echo "---------------检验出@Value注解非常规使用的地方---------------"
  cat checkunnormal.txt | sort -u
fi
checkunconfig=`cat checkunconfig.txt | awk '{if($0!="")print $0}'`;
if [ "${checkunconfig}"x != ""x ];then
  echo "---------------检验出"$unconfigcount" 个@Value注解本地工程存在,而infra/config 工程中没有相应的配置---------------"
  cat checkunconfig.txt | sort -u
fi
rm -f ./remoteconfig.txt ./remoteconfigformat.txt ./checkunnormal.txt ./checkunconfig.txt ./unsetdefaultvalue.txt
