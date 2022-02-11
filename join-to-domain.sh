#!/bin/bash

export LANG=C.UTF-8

f_version() {
    echo -e '
 Сценарий ввода РЕД ОС в домен Windows/SAMBA, FreeIPA
 Version 0.3.15
 Last update: 11-02-2022

'
}


# Считываем входные параметры в переменные
while [ -n "$1" ]; do
      case "$1" in
        -d)
          v_domain=$2 # Имя домена
          ;;
        -n)
          v_name_pc=$2 # Имя ПК
          ;;
        -u)
          v_admin=$2 # Имя администратора домена
          ;;
        -p)
          v_pass_admin=$2 # Пароль администратора домена
          ;;
        -o)
          v_ou=$2 # Имя подразделения
          ;;
       -wg)
           wg=$2 # Имя группы
          ;;
        -y)
          yes=$@ # Подтверждение
          ;;
        -g)
            gui=$@
          ;;
        -w)
            winbind=$@
          ;;
        -h)
            help=$@
          ;;
        -v)
            version=$@
          ;;
     -help)
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
 Скрипт позволяет ввести РЕД ОС в домен Windows(2008/2012/2016/2019), SAMBA или домен IPA.
 Скрипт необходимо запускать с правами пользователя root.
 Параметры запуска ввода в домен Windows/SAMBA:
 -d имя домена
 -n имя компьютера
 -u имя администратора домена
 -o имя подразделения компьютера (OU)
 -p пароль администратора домена
 -y автоматическое подтверждение запросов на выполнение действий при работе скрипта с параметрами
 -w позволяет ввести в домен используя Winbind (по умолчанию применяется SSSD)
 -wg рабочая группа домена (указывается в исключительных случаях)
  ---
 -g запуск скрипта с графическим интерфейсом
 -v вывод версии

 Пример №1 - запуск с параметрами (для Windows/SAMBA):
 join-to-domain.sh -d example.com -n client1 -u admin -p password -y

 Пример №2 - запуск с графическим интерфейсом:
 beesu - "join-to-domain.sh -g"

 Лог (log): /var/log/join-to-domain.log

'
    exit
}


# Если ключ -h или --help , то выводим справку
if [ -n "$help" ]
    then f_help
fi

# Если ключ -v, то выводим версию скрипта
if [ -n "$version" ]
    then f_version
    exit
fi

# Проверка запуска скрипта от root
if [ "$(id -u)" != "0" ]; then
   echo
   echo -e " Ввод РЕД ОС в домен Windows (2008/2012/2016/2019), SAMBA и домен IPA
 Запустите скрипт с правами пользователя root."
   echo
   exit 1
fi

v_date_time=$(date '+%d-%m-%y_%H:%M:%S')
echo -e "\n * * * * * * * * * * *\n Время запуска скрипта: $v_date_time" &>> /var/log/join-to-domain.log
f_version &>> /var/log/join-to-domain.log

# Функция вызова вопроса о продолжении выполнения сценария
myAsk() {
    while true; do
	# Если запущено с gui zenity, то не спрашивать...выполнить break
	if [ -n "$gui" ]; then
	    break
	fi
  if [[ -n "$yes" ]]
  then
    break
  fi
 	read -p " Продолжить выполнение (y/n)? " yn
	case $yn in
	    [Yy]* ) return 0; break;;
	    [Nn]* ) exit;;
	    * ) echo "Ответьте yes или no";;
	esac
    done
}

# Синхронизация с контроллером домена
chrony_conf()
{
  v_date_time=$(date '+%d-%m-%y_%H:%M:%S')
  cp /etc/chrony.conf /etc/chrony.conf.$v_date_time
  sed -i '/server/d' /etc/chrony.conf
  sed -i '/maxdistance/d' /etc/chrony.conf
  echo 'server '$dc' iburst' >> /etc/chrony.conf
  #echo 'maxdistance 16.0' >> /etc/chrony.conf
  systemctl restart chronyd
}

f_choce_pill() {
    while true; do
	# Если запущено с gui zenity, то не спрашивать...выполнить break
	if [ -n "$gui" ]; then
	    break
	fi
  if [ -n "$yes" ]; then
      choce_domain=1
      break
  fi
  echo ""
  echo " Выберите тип домена:"
  echo " 1. Ввод РЕД ОС в домен Windows/SAMBA"
  echo " 2. Ввод РЕД ОС в домен IPA"
 	read -p " Укажите (1 или 2): " choce_domain
	case $choce_domain in
	    [1]* ) return $choce_domain; break;;
	    [2]* ) return $choce_domain; break;;
      [Nn]* ) exit;;
	    * )
	esac
    done
}


# Проверка доступности домена
f_realm_discover()
{
realm discover $v_domain &> /dev/null
if [ $? -ne 0 ];
then echo ' Домен '$v_domain' недоступен! Проверьте настройки сети.' | tee -a /var/log/join-to-domain.log
     exit
  else echo ' Домен '$v_domain' доступен!' | tee -a /var/log/join-to-domain.log
fi
}

# Функция проверки имени ПК
checkname()
{
   if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9\-])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
    then
      true
    else echo -e '\n Ошибка! Недопустимое имя ПК!'
      exit
  fi
}

# Настройка /etc/security/pam_winbind.conf
settings_pam_winbind()
{
sed -i -e 's\;cached_login\cached_login\g' /etc/security/pam_winbind.conf
sed -i -e '/^cached_login/s/no/yes/g' /etc/security/pam_winbind.conf
sed -i -e 's\;krb5_ccache_type =\krb5_ccache_type = FILE\g' /etc/security/pam_winbind.conf
sed -i -e 's\;warn_pwd_expire\warn_pwd_expire\g' /etc/security/pam_winbind.conf
sed -i -e 's\;krb5_auth\krb5_auth\g' /etc/security/pam_winbind.conf
sed -i -e '/^krb5_auth/s/no/yes/g' /etc/security/pam_winbind.conf
}

f_create_form_choce_pill () {
    data=( $(zenity --list --radiolist --title="Ввод в домен" \
    --text="Выберите в какой домен добавить ПК" \
    --column="" \
    --column="Домен" TRUE "Домен Windows/Samba" FALSE "Домен IPA" ))

    # Если zenity NO, то выход из скрипта
    if [ $? -eq 1 ]; then
      exit
    fi
    v_0=${data[0]}
    v_1=${data[1]}

# Если samba
    if [  "$v_1" = "Windows/Samba" ]; then
      select_pill='SAMBA'
    fi
# Если IPA
    if [ "$v_1" = "IPA" ]; then
      select_pill='IPA'
    fi

}


# Функция создания формы ввода в домен IPA
f_create_form_IPA () {
    data_ipa=( $(zenity --forms --separator=" " \
     --title="Ввод в домен FreeIPA" \
     --text="Ввод компьютера в домен IPA" \
     --add-entry="Имя домена:" \
     --add-entry="Имя компьютера:" \
     --add-entry="Имя администратора домена:" \
     --add-password="Пароль администратора:" \
     --ok-label="Да" \
     --cancel-label="Отмена") )

# Если zenity NO, то выход из скрипта
   if [ $? -eq 1 ]; then
     exit
   fi

    v_domain=${data_ipa[0]}
    v_name_pc=${data_ipa[1]}
    v_admin_ipa=${data_ipa[2]}
    v_pass_admin_ipa=${data_ipa[3]}

    # Проверка доступности домена
    realm discover $v_domain &> /dev/null
    if [ $? -ne 0 ];
	then zenity --warning --text 'Домен '$v_domain' недоступен!
Проверьте настройки сети.'
	f_create_form_IPA &> /dev/null
    fi

    # Проверка имени компьютера
    if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9\-])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
	then
	    echo " Имя ПК: $v_name_pc"
	else
	    zenity --warning --text "Ошибка! Недопустимое имя ПК!" &> /dev/null
	    f_create_form_IPA &> /dev/null
    fi

}


# Функция создания формы ввода в домен Windows/Samba
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

   # Если zenity NO, то выход из скрипта
   if [ $? -eq 1 ]; then
	exit
   fi

    v_domain=${data[0]}
    v_name_pc=${data[1]}
    v_admin=${data[2]}
    v_pass_admin_gui=${data[3]}

    # Проверка доступности домена
    realm discover $v_domain &> /dev/null
    if [ $? -ne 0 ];
	then zenity --warning --text 'Домен '$v_domain' недоступен!
Проверьте настройки сети.'
	f_create_form &> /dev/null
    fi

    # Проверка имени компьютера
    if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9\-])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
	then
	    echo " Имя ПК: $v_name_pc"
	else
	    zenity --warning --text "Ошибка! Недопустимое имя ПК!" &> /dev/null
	    f_create_form &> /dev/null
    fi
}

f_msg_exit_domian()
{
  if [ -n "$gui" ]
    then
     zenity --info \
  	 --title="Вывод из домена" \
            --text="Компьютер выведен из домена! Перезагрузите ПК!" \
            --width=210 --height=140 &> /dev/null
  fi
  exit;
}

# Down the Rabbit Hole
f_join_free_ipa()
{
  dc=$(adcli info $v_domain|grep "domain-controller ="| awk '{print $3}')
  chrony_conf # настройка chrony
  hostname_ipa=$v_name_pc.$v_domain
  hostnamectl set-hostname $hostname_ipa
  ipa-client-install --mkhomedir --enable-dns-updates --domain=$v_domain --hostname $hostname_ipa --ntp-server=$dc -p $v_admin_ipa -w $v_pass_admin_ipa -U | tee -a /var/log/join-to-domain.log
  sed -i 's;default_ccache_name = KEYRING:persistent:%{uid};default_ccache_name = FILE:/tmp/krb5cc_%{uid};g' /etc/krb5.conf
}


# Функция вывода из домена
freedom()
{
    find_ipa=$(realm list | grep server-software |  awk '{ print $NF }')
    if [ "$find_ipa" = "ipa" ]
      then
        echo ' Компьютер введен в домен '`domainname -d`.' Вывести компьютер из домена?' | tee -a /var/log/join-to-domain.log
        myAsk
        ipa-client-install --uninstall -U | tee -a /var/log/join-to-domain.log
        successful_out_ipa=$(tail -n1 /var/log/ipaclient-uninstall.log | awk '{ print $NF }')
        successful_out_ipa2=$(grep 'Client uninstall complete' /var/log/ipaclient-uninstall.log | awk  '{ print $NF }')
        if [[ "$successful_out_ipa" = "successful" || "$successful_out_ipa2" = "complete." ]]
          then
            echo ' Компьютер выведен из домена IPA. Перезагрузите ПК!' | tee -a /var/log/join-to-domain.log
            f_msg_exit_domian
          else
              echo "Ошибка вывода из домена IPA, см. /var/log/ipaclient-uninstall.log" | tee -a /var/log/join-to-domain.log
              if [ -n "$gui" ]
                then
                  zenity --error \
                          --title="Вывод из домена IPA" \
                          --text="Ошибка вывода из домена IPA, см. /var/log/ipaclient-uninstall.log" \
                          --no-wrap &> /dev/null
               fi
          exit;
        fi

      fi

    echo ' Компьютер введен в домен '`domainname -d`.' Вывести компьютер из домена?' | tee -a /var/log/join-to-domain.log
    myAsk
    realm leave -v --client-software=sssd
    realm leave -v --client-software=winbind
    sss_cache -E
    kdestroy
echo -e '
[global]
	workgroup = SAMBA
	security = user

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
  directory mask = 0775
' > /etc/samba/smb.conf
    echo
    echo ' Компьютер выведен из домена.' | tee -a /var/log/join-to-domain.log
    f_msg_exit_domian
}


# Проверка на realm list
result_realm=$(realm list)
if [ -z "$result_realm" ]
   then echo -e '\n Ввод РЕД ОС в домен Windows 2008/2012/2016/2019, SAMBA, IPA \n'
   echo ' Этот компьютер не в домене!' | tee -a /var/log/join-to-domain.log
   myAsk
   f_choce_pill
   elif [ -n "$gui" ]
   then (
   zenity --question --title="Компьютер в домене." \
          --text="Компьютер в домене.  Вывести компьютер из домена?" \
          --ok-label="Да" \
          --cancel-label="Отмена" \
          --width=150 --height=150 &> /dev/null
	)
# Если zenity NO, то выход из скрипта
   if [ $? -eq 1 ]
	then
	exit
   fi
# Если zenity Yes, то вывод из домена
   if [ $? -eq 0 ]
	then
	freedom
   fi
   else echo
        freedom

fi

# You have two choices
if [ -n "$gui" ]
    then
      # red pill or blue pill
      f_create_form_choce_pill &> /dev/null
      if [ "$select_pill" = "SAMBA" ]
        then
          f_create_form &> /dev/null
        fi

        if [ "$select_pill" = "IPA" ]
          then
          f_create_form_IPA &> /dev/null
          (f_join_free_ipa) |
          zenity  --title="Ввод в домен!" \
                  --text="Выполняю ввод в домен IPA ..." \
                  --progress --pulsate --auto-close --auto-kill &> /dev/null
          successful_in_ipa=$(tail -n1 /var/log/ipaclient-install.log | awk '{ print $NF }')
          if [ "$successful_in_ipa" = "successful" ]
            then
              zenity --info \
                     --title="Ввод в домен IPA" \
                     --text="Компьютер успешно введен в домен IPA! Перезагрузите ПК" \
                     --no-wrap &> /dev/null
              exit;
          else
            zenity --error \
                   --title="Ввод в домен IPA" \
                   --text="Ошибка ввода в домен IPA, см. /var/log/ipaclient-install.log" \
                   --no-wrap &> /dev/null
            exit;
          fi
      fi
fi

# Ввод в домен IPA (терминальный)
# Follow the white rabbit
if [ "$choce_domain" = "2" ]
then
  echo
  echo -e ' Для ввода РЕД ОС в домен IPA, введите имя домена.\n Пример: example.com\n'
  read -p ' Имя домена: ' v_domain
  echo ' Введите имя ПК. Пример: client1'

  while true; do
	  read -p ' Имя ПК: ' v_name_pc
	   if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9\-])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
	  then
	     break;
	     else echo -e '\n Ошибка! Недопустимое имя ПК!'
	  fi
	done

	read -p ' Имя администратора домена: ' v_admin_ipa
  f_realm_discover
  read -sp  " Введите пароль администратора домена IPA: " v_pass_admin_ipa && echo
  myAsk
  f_join_free_ipa
  successful_in_ipa=$(tail -n1 /var/log/ipaclient-install.log | awk '{ print $NF }')
  if [ "$successful_in_ipa" = "successful" ]
    then
    echo
    echo " РЕД ОС успешно введён в домен IPA! Перезагрузите ПК."
  else echo -e '\n Ошибка ввода в домен IPA, см. /var/log/ipaclient-install.log'
  fi
  exit;
fi


# Если входных параметров скрипта нет, то ...
if [[ -z "$v_domain"  &&  -z "$v_name_pc"  &&  -z "$v_admin" && -z "$gui" &&  -z "$v_ou" ]];
  then
      echo -e ' Для ввода РЕД ОС в домен Windows/SAMBA, введите имя домена.\n Пример: example.com\n'
      read -p ' Имя домена: ' v_domain
      echo ' Введите имя ПК. Пример: client1'

	while true; do
	  read -p ' Имя ПК: ' v_name_pc
	   if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9\-])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
	  then
	     break;
	     else echo -e '\n Ошибка! Недопустимое имя ПК!'
	  fi
	done

	read -p ' Имя администратора домена: ' v_admin
	read -p ' Укажите имя подразделения(OU) ПК или для продолжения нажмите ENTER:' v_ou
# Проверка входных параметров
   elif [[ -z "$v_admin" ]]
        then echo " Ошибка. Введите имя администратора домена. Используйте параметр -u"
	exit
   elif [[ -z "$v_name_pc" ]]
        then echo " Ошибка. Введите имя ПК. Используйте параметр -n"
        exit
   elif [[ -z "$v_domain" ]]
        then echo " Ошибка. Введите имя домена. Используйте параметр -d"
        exit
   elif [[ -z "$v_ou" ]]
        then echo " Имя подразделения(OU) для ПК по умолчанию - 'Computers'. Для изменения используйте параметр -o"
   else
   checkname || exit;
fi

# Параметр для добавления ПК в определенную организационную единицу (подразделение)
if [[ ! -z "$v_ou" ]];
   then
	v_ou_net_ads='createcomputer='$v_ou
    v_ou_realm_join='--computer-ou=OU='$v_ou
fi

# Настройка nsswitch.conf
v_date_time=$(date '+%d-%m-%y_%H:%M:%S')
cp /etc/authselect/user-nsswitch.conf /etc/authselect/user-nsswitch.conf.$v_date_time &> /dev/null
authselect select sssd --force &> /dev/null
sed -i 's/\bhosts:.*/hosts:      files dns resolve [!UNAVAIL=return] myhostname mdns4_minimal/g' /etc/authselect/user-nsswitch.conf
authselect apply-changes &> /dev/null

# Проверка доступности домена
f_realm_discover

# realm join console
if [[ -z "$v_pass_admin_gui" &&  -z "$v_pass_admin" ]];
then
  read -sp  " Введите пароль администратора домена: " v_pass_admin && echo
fi

# Вызов функции диалога
if [[ -z "$yes" ]]
then
    myAsk
fi


echo -e '' >> /var/log/join-to-domain.log
# Установка дополнительных пакетов
echo -e ' 1) Установка дополнительных пакетов.' | tee -a /var/log/join-to-domain.log
yum install -y realmd sssd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation &>> /var/log/join-to-domain.log

echo -e ' 2) Изменение имени ПК' | tee -a /var/log/join-to-domain.log
hostnamectl set-hostname $v_name_pc.$v_domain
echo -e '    Новое имя ПК: '`hostname` | tee -a /var/log/join-to-domain.log

dc=$(adcli info $v_domain|grep "domain-controller ="| awk '{print $3}')
v_date_time=$(date '+%d-%m-%y_%H:%M:%S')

# Настройка chronyd
echo -e ' 3) Настройка chronyd' | tee -a /var/log/join-to-domain.log
chrony_conf

# Настройка hosts
echo -e ' 4) Настройка hosts' | tee -a /var/log/join-to-domain.log
cp /etc/hosts /etc/hosts.$v_date_time
echo -e '127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4' > /etc/hosts
echo -e '::1 localhost localhost.localdomain localhost6 localhost6.localdomain6' >> /etc/hosts
echo -e '127.0.0.1  '$(hostname -f)' '$(hostname -s)'' >> /etc/hosts

# Короткое имя домена
v_short_domen=$(cut -d'.' -f2 <<< "$dc")
# Короткое имя домена в верхнем регистре
v_BIG_SHORT_DOMEN=$(tr [:lower:] [:upper:] <<< "$v_short_domen")
# Полное имя домена в верхнем регистре
v_BIG_DOMAIN=$(tr [:lower:] [:upper:] <<< "$v_domain")
domainname=$(domainname -d)

# Настройка krb5.conf
echo -e ' 5) Настройка krb5.conf' | tee -a /var/log/join-to-domain.log
cp /etc/krb5.conf /etc/krb5.conf.$v_date_time
echo -e 'Информация о домене:' >> /var/log/join-to-domain.log
adcli info $v_domain &>> /var/log/join-to-domain.log
dc_list=$(adcli info $v_domain | grep domain-controllers | cut -d ' ' -f 3-4)
kdc1=$(echo $dc_list | awk  '{print($1)}')
kdc2=$(echo $dc_list | awk  '{print($2)}')
krb5_kdc1="kdc = $kdc1"
if [[ $kdc2 == "" ]] ; then
   krb5_kdc2=""
  else
   krb5_kdc2="kdc = $kdc2"
fi


echo -e 'includedir /etc/krb5.conf.d/

[logging]
    default = FILE:/var/log/krb5libs.log
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmind.log

[libdefaults]
# Отключить поиск kerberos-имени домена через DNS
    dns_lookup_realm = false
# Включить поиск kerberos-настроек домена через DNS
    dns_lookup_kdc = true
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    pkinit_anchors = /etc/pki/tls/certs/ca-bundle.crt
    spake_preauth_groups = edwards25519
    default_ccache_name = FILE:/tmp/krb5cc_%{uid}
    default_realm = '$v_BIG_DOMAIN'

    default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 RC4-HMAC DES-CBC-CRC DES3-CBC-SHA1 DES-CBC-MD5
    default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 RC4-HMAC DES-CBC-CRC DES3-CBC-SHA1 DES-CBC-MD5
    preferred_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 RC4-HMAC DES-CBC-CRC DES3-CBC-SHA1 DES-CBC-MD5

[realms]
'$v_BIG_DOMAIN' = {
    '$krb5_kdc1' # Primary Domain Controller
    '$krb5_kdc2'
    admin_server = '$kdc1' # Primary Domain Controller
    default_domain = '$v_domain' # Domain name
}

[domain_realm]
.'$v_domain' = '$v_BIG_DOMAIN'
'$v_domain' = '$v_BIG_DOMAIN'
' > /etc/krb5.conf

#------------------------------------------------------------------------------#
# Ввод в домен с использованием winbind (консольно, через передачу параметров) #
#------------------------------------------------------------------------------#
# Выполняется если указан ключ -w
if [ -n "$winbind" ]
then
    if [ -n "$wg" ] ; then
       v_domain=$wg
    fi
sed -i "s/SELINUX=enforcing/SELINUX=permissive/" /etc/selinux/config
setenforce 0
systemctl disable sssd
systemctl stop sssd
echo -e ' 6) Ввод в домен (winbind) ...' | tee -a /var/log/join-to-domain.log
realm join -vvv -U $v_admin --client-software=winbind $v_domain <<< $v_pass_admin &>> /var/log/join-to-domain.log
if [ $? -ne 0 ];
  then echo '    Ошибка ввода в домен, см. /var/log/join-to-domain.log' | tee -a /var/log/join-to-domain.log
       exit;
fi

echo -e ' 7) Выполняется authselect' | tee -a /var/log/join-to-domain.log
authselect select winbind with-mkhomedir with-krb5 --force &>> /var/log/join-to-domain.log
authselect enable-feature with-mkhomedir &>> /var/log/join-to-domain.log

# samba config log
echo -e ' 8) Настройка samba' | tee -a /var/log/join-to-domain.log

# backup smb.conf
cp /etc/samba/smb.conf /etc/samba/smb.conf.$v_date_time

# Настройка smb.conf
mkdir -p /var/lib/domain/
mkdir -p /var/lib/domain/run
echo -e '[global]
    workgroup = '$v_BIG_SHORT_DOMEN'
    realm = '$v_BIG_DOMAIN'
    security = ADS

    winbind enum groups = Yes
    winbind enum users = Yes
    winbind offline logon = Yes
    winbind refresh tickets = Yes

#   Формат логина: domain\username
    winbind use default domain = no

    winbind refresh tickets = Yes
    winbind cache time = 300
    wins support = no

    idmap cache time = 900
    idmap config * : backend = tdb
    idmap config * : range = 10000-99999
    idmap config '$v_BIG_SHORT_DOMEN' : backend = rid
    idmap config '$v_BIG_SHORT_DOMEN' : range = 100000-999999

    client min protocol = NT1
    client max protocol = SMB3

    kerberos method = system keytab

#   Домашний каталог пользователя:  template homedir = /home/%D/%U
    template homedir = /home/%U@%D

    template shell = /bin/bash
    nt pipe support = no
    machine password timeout = 60
    vfs objects = acl_xattr
    map acl inherit = yes
    store dos attributes = yes

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

echo -e ' 9) Тест конфигурации samba' | tee -a /var/log/join-to-domain.log
echo -e "\n" | testparm &>> /var/log/join-to-domain.log

# Настройка limits
cp /etc/security/limits.conf /etc/security/limits.conf.$v_date_time
echo -e '*     -  nofile  16384
root  -  nofile  16384' > /etc/security/limits.conf

# join to domain
join_to_domain() {
    if [[ $wg == "" ]] ; then
      echo -e ' 10) Выполняю net ads join' | tee -a /var/log/join-to-domain.log
      net ads join -S "${kdc1}" -U "${v_admin}%${v_pass_admin}" &>> /var/log/join-to-domain.log
      else
      echo -e ' 10) Выполняю net ads join' | tee -a /var/log/join-to-domain.log
      net ads join -S "${kdc1}" -U "${v_admin}%${v_pass_admin}" -W "$wg" &>> /var/log/join-to-domain.log
    fi

    if [[ $? != 0 ]]; then
        return 1
    fi
}
join_to_domain

# Запуск сервисов
echo -e ' 11) Запуск сервиса winbind' | tee -a /var/log/join-to-domain.log
systemctl enable winbind --now &>> /var/log/join-to-domain.log
echo -e ' 12) Запуск сервиса smb' | tee -a /var/log/join-to-domain.log
systemctl enable smb --now &>> /var/log/join-to-domain.log

# Настройка /etc/security/pam_winbind.conf
settings_pam_winbind
echo -e ' Внимание! Для вступления изменений в силу требуется перезагрузка компьютера!' | tee -a /var/log/join-to-domain.log
exit;
fi

#------------------------------------------------------------------------------#


# realm join in GUI
if [[ -n "$v_pass_admin_gui" ]];
then
  echo -e ' 6) Ввод в домен (GUI)...' | tee -a /var/log/join-to-domain.log
(
    realm join -vvv -U $v_admin $kdc1 <<< $v_pass_admin_gui &>> /var/log/join-to-domain.log
    if [ "$?" = 1 ]; then
        touch /tmp/realm-join-error
    fi
) |
zenity  --title="Ввод в домен!" \
        --text="Выполняю ввод в домен..." \
        --progress --pulsate --auto-close --auto-kill &> /dev/null
fi

# Если файл ошибки(realm join...) существует, то выводим ошибку и выходим из сценария.
if [ -f "/tmp/realm-join-error" ]
then
    zenity --error \
           --title="Ввод в домен" \
           --text="Ошибка ввода в домен, см. /var/log/join-to-domain.log" \
           --no-wrap &> /dev/null
    rm -rf /tmp/realm-join-error
    exit;
fi

# realm join in console
if [[ -z "$v_pass_admin_gui" ]]
then
  echo -e ' 6) Ввод в домен ...' | tee -a /var/log/join-to-domain.log
  realm join -vvv -U $v_admin $kdc1 $v_ou_realm_join <<< $v_pass_admin &>> /var/log/join-to-domain.log
  if [ $? -ne 0 ];
    then echo '    Ошибка ввода в домен, см. /var/log/join-to-domain.log' | tee -a /var/log/join-to-domain.log
         exit;
  fi
fi


# Настройка sssd.conf
echo -e ' 7) Настройка sssd' | tee -a /var/log/join-to-domain.log
cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf.$v_date_time
echo -e '[sssd]
domains = '$domainname'
config_file_version = 2
services = nss, pam

[domain/'$domainname']
ad_domain = '$domainname'
ad_server = '$kdc1'
krb5_realm = '$v_BIG_DOMAIN'
case_sensitive = Preserving
realmd_tags = manages-system joined-with-samba

# Кэширование аутентификационных данных, необходимо при недоступности домена
cache_credentials = True

id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True

# Включает/Отключает режим полных имён пользователей при входе
use_fully_qualified_names = False

# Определение домашнего каталога для доменных пользователей
fallback_homedir = /home/%u@%d

access_provider = ad
ad_gpo_access_control = permissive

# Включает/Отключает перечисление всех записей домена, операция(id или getent) может занимать длительное время при enumerate = ture в больших инфраструктурах
enumerate = false

# Поиск ссылок может привести к снижению производительности в средах, которые их интенсивно используют. Примечательным примером является Microsoft Active Directory.
#  true - не рекомендуется для больших инфраструктур. Отключаем этот поиск.
ldap_referrals = false

# Включает/Отключает динамические обновления DNS, если в статусе sssd ошибка "TSIG error with server: tsig verify failure", то присвоить dyndns_update = false
dyndns_update = true
dyndns_refresh_interval = 43200
dyndns_update_ptr = true
dyndns_ttl = 3600

[nss]
# Сколько секунд nss_sss должен кэшировать перечисления (запросы информации обо всех пользователях) Default: 120
#entry_cache_timeout = 15
# Задает время в секундах, в течение которого список поддоменов будет считаться действительным. Default: 60
#get_domains_timeout = 10
' > /etc/sssd/sssd.conf


if [[ -n "$v_pass_admin_gui" ]];
then
(
    authconfig --enablemkhomedir --enablesssdauth --updateall &>> /var/log/join-to-domain.log; sleep 2
) |
  zenity --progress --title="Ввод в домен" --text="Настройка сервиса sssd" --pulsate --auto-close &> /dev/null
fi


if [[ -z "$v_pass_admin_gui" ]];
then
    authconfig --enablemkhomedir --enablesssdauth --updateall &>> /var/log/join-to-domain.log
fi


# Настройка limits
echo -e ' 8) Настройка limits' | tee -a /var/log/join-to-domain.log
cp /etc/security/limits.conf /etc/security/limits.conf.$v_date_time
echo -e '*     -  nofile  16384
root  -  nofile  16384' > /etc/security/limits.conf


# samba config log
echo -e ' 9) Настройка samba' | tee -a /var/log/join-to-domain.log

# backup smb.conf
cp /etc/samba/smb.conf /etc/samba/smb.conf.$v_date_time

# Настройка smb.conf
echo -e '[global]
    workgroup = '$v_BIG_SHORT_DOMEN'
    realm = '$v_BIG_DOMAIN'
    security = ADS
    passdb backend = tdbsam

    winbind enum groups = Yes
    winbind enum users = Yes
    winbind offline logon = Yes
    winbind refresh tickets = Yes
    winbind use default domain = Yes
    winbind refresh tickets = Yes

    idmap cache time = 900
    idmap config * : backend = tdb
    idmap config * : range = 10000-99999
    idmap config '$v_BIG_SHORT_DOMEN' : backend = rid
    idmap config '$v_BIG_SHORT_DOMEN' : range = 100000-999999

    client min protocol = NT1
    client max protocol = SMB3

    dedicated keytab file = /etc/krb5.keytab
    kerberos method = secrets and keytab

    machine password timeout = 60
    vfs objects = acl_xattr
    map acl inherit = yes
    store dos attributes = yes

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

# Настройка /etc/security/pam_winbind.conf
settings_pam_winbind

# net ads in GUI
if [[ -n "$v_pass_admin_gui" ]];
then
echo -e ' 10) Ввод samba в домен (GUI)...' | tee -a /var/log/join-to-domain.log
(
    net ads join -U $v_admin%$v_pass_admin_gui -D $v_domain &>> /var/log/join-to-domain.log
    if [ "$?" = 1 ]; then
        touch /tmp/net-ads-join-error
    fi
sleep 2
) |
zenity  --title="Ввод в домен!" \
        --text="Выполняю команду net ads join..." \
        --progress --pulsate --auto-close --auto-kill &> /dev/null
fi

if [ -f "/tmp/net-ads-join-error" ]
then
    zenity --error \
           --title="Ввод в домен" \
           --text="Ошибка ввода в домен, см. /var/log/join-to-domain.log" \
           --no-wrap &> /dev/null
rm -rf /tmp/net-ads-join-error
exit;
fi

# net ads in console
if [[ -z "$v_pass_admin_gui" ]]
then
	echo -e ' 10) Ввод samba в домен...' | tee -a /var/log/join-to-domain.log
	net ads join -U $v_admin%$v_pass_admin -D $v_domain $v_ou_net_ads &>> /var/log/join-to-domain.log
fi

echo '    Лог установки: /var/log/join-to-domain.log'
echo
echo '    Выполнено. Компьютер успешно введен в домен! Перезагрузите ПК.' | tee -a /var/log/join-to-domain.log
if [ -n "$gui" ]
  then
    zenity --info \
           --title="Ввод в домен" \
           --text="Компьютер успешно введен в домен! Перезагрузите ПК." \
           --no-wrap &> /dev/null
fi
exit;
