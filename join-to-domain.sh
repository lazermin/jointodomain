#!/bin/bash

# Last update: 17-12-2020
#
# Сценарий ввода сетевого хоста Linux в домен Windows


export LANG=C.UTF-8

#Считываем входные параметры в переменные
while [ -n "$1" ]; do
      case "$1" in
        -d)
          v_domain=$2 #Имя домена
          ;;
        -n)
          v_name_pc=$2 #Имя ПК
          ;;
        -u)
          v_admin=$2 #Имя администратор домена
          ;;
        -p)
          v_pass_admin=$2 #Пароль администратор домена
          ;;
        -g)
            gui=$@
          ;;
        -h)
            help=$@
          ;;
    --help)
            help=$@
          ;;
      esac
      shift
done


f_help() {
    echo -e '
 Скрипт ввода компьютера в домен Windows 2008/2012/2016
 Скрипт необходимо запускать с правами пользователя root.
 Параметры запуска:
 -d имя_домена
 -n имя_компьютера
 -u имя_администратора_домена
 -p пароль администратора домена
 -g запуск графического интерфейса 
 Пример №1 - запуск с параметрами: join-to-domain.sh -d example.com -n client1 -u admin -p password
 Пример №2 - запуск с графическим интерфейсом: beesu - "join-to-domain.sh -g"

 Лог скрипта: /var/log/domain-join-cli.log
'
    exit
}

#Если ключ -h или --help , то выводим справку
if [ -n "$help" ]
    then f_help
fi

#Проверка запуска скрипта от root
if [ "$(id -u)" != "0" ]; then
   echo -e " Скрипт ввода компьютера в домен Windows 2008/2012/2016
 Запустите скрипт под пользователем root"
   exit 1
fi

v_date_time=$(date '+%d-%m-%y_%H:%M:%S')
echo -e "\n * * * * * * * * * * *\n Время запуска скрипта: $v_date_time" &>> /var/log/domain-join-cli.log


#Функция вызова диалога вопроса продолжения выполнения скрипта
myAsk() {
    while true; do
	#Если запущено gui zenity, то не спрашивать...выполнить break
	if [ -n "$gui" ]; then
	    break
	fi
	read -p " Продолжить выполнение (y/n)? " yn
	case $yn in
	    [Yy]* ) return 0; break;;
	    [Nn]* ) exit;;
	    * ) echo "Ответе yes или no.";;
	esac
    done
}

#Функция проверка имени ПК
checkname()
{
   if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
    then
      true
    else echo -e '\n Ошибка! Недопустимое имя ПК!'      
      exit
  fi
}

#Функция создания основной формы zenity ввода в домен
f_create_form () {
    data=( $(zenity --forms --separator=" " \
     --title="Ввод в домен" \
     --text="Ввод компьютера в домен" \
     --add-entry="Имя домена:" \
     --add-entry="Имя компьютера:" \
     --add-entry="Имя администратора домена:" \
     --add-password="Пароль администратора:" \
     --ok-label="Да" \
     --cancel-label="Отмена") )

    #Если zenity NO, то выход из скрипта
   if [ $? -eq 1 ]; then
	exit
   fi

    v_domain=${data[0]}
    v_name_pc=${data[1]}
    v_admin=${data[2]}
    v_pass_admin=${data[3]}


    #Проверка доступности домена
    realm discover $v_domain &> /dev/null
    if [ $? -ne 0 ];
	then zenity --warning --text 'Домен '$v_domain' недоступен!
Проверьте настройки сети.'
	f_create_form &> /dev/null
    fi

    #Проверка имени компьютера
    if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
	then
	    echo " Имя ПК: $v_name_pc"
	else
	    zenity --warning --text "Ошибка! Недопустимое имя ПК!" &> /dev/null
	    f_create_form &> /dev/null
    fi
}

#Функция вывода из домена
domain_exit()
{
   echo ' Компьютер введен в домен '`domainname -d`.' Вывести компьютер из домена?' | tee -a /var/log/domain-join-cli.log
   myAsk	
   realm leave -v --client-software=sssd
   realm leave -v --client-software=winbind
   echo
   echo ' Компьютер выведен из домена.' | tee -a /var/log/domain-join-cli.log
if [ -n "$gui" ]
  then
   zenity --info \
	 --title="Вывод из домена" \
          --text="Компьютер выведен из домена!" \
          --no-wrap &> /dev/null
fi
   exit
}

#Проверка на realm list
result_realm=$(realm list)
if [ -z "$result_realm" ]
   then echo -e '\n Скрипт ввода компьютера в домен Windows 2008/2012/2016 \n'
	    echo ' Этот компьютер не в домене.' | tee -a /var/log/domain-join-cli.log

   elif [ -n "$gui" ]
   then (
   zenity --question --title="Компьютер в домене." \
          --text="Компьютер в домене.  Вывести компьютер из домена?" \
          --ok-label="Да" \
          --cancel-label="Отмена" \
          --width=150 --height=150 &> /dev/null
	)	
#Если zenity NO, то выход из скрипта
   if [ $? -eq 1 ]
	 then
	  exit
   fi
#Если zenity Yes, то вывод из домена	
   if [ $? -eq 0 ]
	 then
	 domain_exit
   fi
   else echo
        domain_exit

fi

if [ -n "$gui" ]
    then
    f_create_form &> /dev/null
fi

#Если входных параметров скрипта нет, то ...
if [[ -z "$v_domain"  &&  -z "$v_name_pc"  &&  -z "$v_admin" && -z "$gui" ]];
  then
      echo -e ' Для ввода ПК в домен, введите имя домена.\n Пример: example.com\n'
      read -p ' Имя домена: ' v_domain
      echo ' Введите имя ПК. Пример: client1'

	while true; do
	  read -p ' Имя ПК: ' v_name_pc
	   if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
	  then
	     break;
	     else echo -e '\n Ошибка! Недопустимое имя ПК!'
	  fi
	done

      read -p ' Имя администратора домена: ' v_admin
   #Проверка входных параметров
   elif [[ -z "$v_admin" ]]
        then echo " Ошибка. Введите имя администратора домена. Используйте параметр -u"
	    exit
   elif [[ -z "$v_name_pc" ]]
        then echo " Ошибка. Введите имя ПК. Используйте параметр -n"
        exit
   elif [[ -z "$v_domain" ]]
        then echo " Ошибка. Введите имя домена. Используйте параметр -d"
        exit
   else
   checkname || exit;
fi


#Проверка на домен local
if grep 'local$' <<< $v_domain &> /dev/null
then
    v_date_time=$(date '+%d-%m-%y_%H:%M:%S')
    cp /etc/nsswitch.conf /etc/nsswitch.conf.$v_date_time
    sed -i 's/mdns4_minimal \[NOTFOUND=return\]//' /etc/nsswitch.conf
fi

#Проверка доступности домена
realm discover $v_domain &> /dev/null
if [ $? -ne 0 ];
then echo ' Домен '$v_domain' недоступен! Проверьте настройки сети.' | tee -a /var/log/domain-join-cli.log
     exit
  else echo ' Домен '$v_domain' доступен!' | tee -a /var/log/domain-join-cli.log
fi


#Вызов функции диалога
myAsk


echo -e '' >> /var/log/domain-join-cli.log
#install soft
echo -e ' 1) Установка дополнительных пакетов.' | tee -a /var/log/domain-join-cli.log
yum install -y realmd sssd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation &>> /var/log/domain-join-cli.log

echo -e ' 2) Изменение имени ПК' | tee -a /var/log/domain-join-cli.log
hostnamectl set-hostname $v_name_pc.$v_domain
echo -e '    Новое имя ПК: '`hostname` | tee -a /var/log/domain-join-cli.log

dc=$(adcli info $v_domain|grep "domain-controller ="| awk '{print $3}')
v_date_time=$(date '+%d-%m-%y_%H:%M:%S')

#Настройка chronyd
echo -e ' 3) Настройка chronyd' | tee -a /var/log/domain-join-cli.log
cp /etc/chrony.conf /etc/chrony.conf.$v_date_time
sed -i '/server/d' /etc/chrony.conf
echo 'server '$dc' iburst' >> /etc/chrony.conf
systemctl restart chronyd

#Настройка hosts
echo -e ' 4) Настройка hosts' | tee -a /var/log/domain-join-cli.log
cp /etc/hosts /etc/hosts.$v_date_time
echo -e '127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4' > /etc/hosts
echo -e '::1 localhost localhost.localdomain localhost6 localhost6.localdomain6' >> /etc/hosts
echo -e '127.0.0.1  '$(hostname -f)' '$(hostname -s)'' >> /etc/hosts

#realm join
if [[ -n "$v_pass_admin" ]]
then
  echo -e ' 5) Ввод в домен...' | tee -a /var/log/domain-join-cli.log
  realm join -U -v $v_admin $v_domain <<< $v_pass_admin &>> /var/log/domain-join-cli.log
  if [ $? -ne 0 ];
  then echo '    Ошибка ввода в домен, см. /var/log/domain-join-cli.log' | tee -a /var/log/domain-join-cli.log
       exit;
  fi

fi

if [[ -z "$v_pass_admin" ]]
then
  echo -e ' 5) Ввод в домен...' | tee -a /var/log/domain-join-cli.log
  read -sp  "Введите пароль администратора домена: " password && echo
  realm join -U -v $v_admin $v_domain <<< $password &>> /var/log/domain-join-cli.log
  if [ $? -ne 0 ];
    then echo '    Ошибка ввода в домен, см. /var/log/domain-join-cli.log' | tee -a /var/log/domain-join-cli.log
         exit;
  fi

fi

#Короткое имя домена
v_short_domen=$(cut -d'.' -f2 <<< "$dc")
#Короткое имя домена в верхнем регистре
v_BIG_SHORT_DOMEN=$(tr [:lower:] [:upper:] <<< "$v_short_domen")
#Полное имя домена в верхнем регистре
v_BIG_DOMAIN=$(tr [:lower:] [:upper:] <<< "$v_domain")
domainname=$(domainname -d)

#Настройка sssd.conf
echo -e ' 6) Настройка sssd' | tee -a /var/log/domain-join-cli.log
cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf.$v_date_time
echo -e '[sssd]
domains = '$domainname'
config_file_version = 2
services = nss, pam

[domain/'$domainname']
ad_domain = '$domainname'
krb5_realm = '$v_BIG_DOMAIN'
realmd_tags = manages-system joined-with-samba
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = False
fallback_homedir = /home/%u@%d
access_provider = ad
ad_gpo_access_control = permissive' > /etc/sssd/sssd.conf

authconfig --enablemkhomedir --enablesssdauth --updateall &>> /var/log/domain-join-cli.log

#limits
echo -e ' 7) Настройка limits' | tee -a /var/log/domain-join-cli.log
cp /etc/security/limits.conf /etc/security/limits.conf.$v_date_time
echo -e '*     -  nofile  16384
root  -  nofile  16384' > /etc/security/limits.conf


#Настройка krb5.conf
echo -e ' 8) Настройка krb5.conf' | tee -a /var/log/domain-join-cli.log
cp /etc/krb5.conf /etc/krb5.conf.$v_date_time

echo -e 'includedir /etc/krb5.conf.d/

[logging]
    default = FILE:/var/log/krb5libs.log
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmind.log

[libdefaults]
    dns_lookup_realm = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    pkinit_anchors = /etc/pki/tls/certs/ca-bundle.crt
    spake_preauth_groups = edwards25519
    default_ccache_name = FILE:/tmp/krb5cc_%{uid}
    default_realm = '$v_BIG_DOMAIN'

[realms]
# EXAMPLE.COM = {
#     kdc = kerberos.example.com
#     admin_server = kerberos.example.com
# }

[domain_realm]
# .example.com = EXAMPLE.COM
# example.com = EXAMPLE.COM' > /etc/krb5.conf


#samba config log
echo -e ' 9) Настройка samba' | tee -a /var/log/domain-join-cli.log

#backup smb.conf
cp /etc/samba/smb.conf /etc/samba/smb.conf.$v_date_time

#Настройка smb.conf
echo -e '[global]
    workgroup = '$v_BIG_SHORT_DOMEN'
    realm = '$v_BIG_DOMAIN'
    security = ADS
    idmap config * : range = 10000-99999
    client min protocol = NT1
    client max protocol = SMB3
    dedicated keytab file = /etc/krb5.keytab
    kerberos method = secrets and keytab
    winbind refresh tickets = Yes
    machine password timeout = 60
    vfs objects = acl_xattr
    map acl inherit = yes
    store dos attributes = yes

    passdb backend = tdbsam
    printing = cups
    printcap name = cups
    load printers = yes
    cups options = raw

[homes]
    comment = Home Directories
    valid users = %S, %D%w%S
    browseable = No
    read only = No
    inherit acls = Yes

[printers]
    comment = All Printers
    path = /var/tmp
    printable = Yes
    create mask = 0600
    browseable = No

[print$]
    comment = Printer Drivers
    path = /var/lib/samba/drivers
    write list = @printadmin root
    force group = @printadmin
    create mask = 0664
    directory mask = 0775' > /etc/samba/smb.conf
if [[ -n "$v_pass_admin" ]]
then
echo -e ' 10) Ввод samba в домен...' | tee -a /var/log/domain-join-cli.log
net ads join -U $v_admin -D $v_domain <<< $v_pass_admin &>> /var/log/domain-join-cli.log
fi

if [[ -z "$v_pass_admin" ]]
then
echo -e ' 10) Ввод samba в домен...' | tee -a /var/log/domain-join-cli.log
net ads join -U $v_admin -D $v_domain <<< $password &>> /var/log/domain-join-cli.log
fi

echo '    Лог установки: /var/log/domain-join-cli.log'
echo
echo '    Выполнено. Компьютер успешно введен в домен!' | tee -a /var/log/domain-join-cli.log
if [ -n "$gui" ]
  then
    zenity --info \
           --title="Ввод в домен" \
           --text="Компьютер успешно введен в домен!" \
           --no-wrap &> /dev/null
fi
exit
