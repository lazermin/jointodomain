#!/bin/bash
export LANG=C.UTF-8

f_version() {
    echo -e '
 Сценарий ввода РЕД ОС в домен Windows/SAMBA, FreeIPA
 Version 0.5.8
 Last update: 28-12-2022

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
            --ou)
                v_ou=$2 # Имя подразделения
                ;;
            --dc)
                v_kdc=$2 # Имя(FQDN) контроллера домена
                ;;
            --wg)
                wg=$2 # Имя домена (пред-Windows 2000)
                ;;
              -w)
                winbind=$@
                ;;
              -y)
                yes=$@ # Подтверждение
                ;;
      -f|--force)
                force=$@ # Ввод в домен под своим прежним именем ПК
                ;;
--sssd-lower-case)
                v_slc=$@ # Имя пользователя в нижнем регистре
                ;;
--delete-computer)
                del_pc=$@
                ;;
         -g|--gui)
                gui=$@
                ;;
        -h|--help)
                help=$@
                ;;
     -v|--version)
                version=$@
                ;;
    esac
    shift
done

RED='\033[1;31m'
YEL='\033[1;33m'
BLU='\033[1;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

f_help() {
    echo -e '
 Скрипт позволяет ввести РЕД ОС в домен Windows(2008/2012/2016/2019/2022), SAMBA или домен IPA.
 Скрипт необходимо запускать с правами пользователя root.
 Параметры:
                -d Имя домена
                -n Имя компьютера
                -u Имя администратора домена
                -p Пароль администратора домена
              --ou Имя подразделения компьютера (OU), формат ввода "OU=МоиПК,OU=ОтделIT". Порядок указания OU снизу вверх
              --dc Имя контроллера домена
                -w Позволяет ввести в домен, используя Winbind (по умолчанию применяется SSSD)
                -y Автоматическое подтверждение запросов на выполнение действий при работе скрипта с параметрами
       -f, --force Принудительный ввод в домен (вывод из домена) под своим прежним именем ПК (игнорируется существующая учетная запись ПК в домене)
              --wg Указать "Имя домена (пред-Windows 2000)", необязательный ключ
 --delete-computer Удаляет учётную запись ПК из домена (не выводит сам ПК из домена), см. пример №3
 --sssd-lower-case Принудительно устанавливает имя пользователя в нижнем регистре
         -g, --gui Запуск скрипта с графическим интерфейсом
        -h, --help Показать справку
     -v, --version Вывод версии

 Пример №1 - запуск с параметрами (для Windows/SAMBA):
 join-to-domain.sh -d <domain_name> -n <pc_name> -u <admin_login> -p <password> -y
 join-to-domain.sh -d <domain_name> -n <pc_name> -u <admin_login> --dc <domain_controller> -y

 Пример №2 - ввод в домен с добавлением ПК в OU:
 join-to-domain.sh -d <domain_name> -n <pc_name> -u <admin_login> -p <password> --ou "OU=МоиПК,OU=ОтделIT" -y

 Пример №3 - удаление учетной записи ПК с подключением к определенному контроллеру:
 join-to-domain.sh --delete-computer -u <admin_login> -d <domain_name> --dc <domain_controller> -n <pc_name>

 Журнал событий: /var/log/join-to-domain.log

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
   echo -e " Ввод РЕД ОС в домен Windows (2008/2012/2016/2019/2022), SAMBA и домен IPA
 Запустите скрипт с правами пользователя root."
   echo
   exit 1
fi

# Если ключ --delete-computer, то удаляем УЗ ПК из домена
if [ -n "$del_pc" ]
	then
	if [[ -z "$v_admin" ]]
        then echo -e " ${RED}Ошибка. Введите имя администратора домена. Используйте параметр -u${NC}"
        exit 1;
    elif [[ -z "$v_name_pc" ]]
        then echo -e " ${RED}Ошибка. Введите имя ПК. Используйте параметр -n${NC}"
        exit 1;
    elif [[ -z "$v_domain" ]]
        then echo -e " ${RED}Ошибка. Введите имя домена. Используйте параметр -d${NC}"
        exit 1;
    fi
	echo -e "" &>> /var/log/join-to-domain.log
	echo -e 'Deleting a PC account' &>> /var/log/join-to-domain.log
	if [ -n "$v_kdc" ]
		then
		adcli delete-computer -U $v_admin -S $v_kdc --domain=$v_domain $v_name_pc
		echo -e 'End Deleting PC'  &>> /var/log/join-to-domain.log
		echo -e "" &>> /var/log/join-to-domain.log
	else
		adcli delete-computer -U $v_admin --domain=$v_domain $v_name_pc
		echo -e 'End Deleting PC'  &>> /var/log/join-to-domain.log
		echo -e "" &>> /var/log/join-to-domain.log
	fi
    exit
fi

v_date_time=$(date '+%d-%m-%y_%H:%M:%S')
echo -e "\n * * * * * * * * * * *\n Время запуска скрипта: $v_date_time" &>> /var/log/join-to-domain.log
f_version &>> /var/log/join-to-domain.log
uname -a &>> /var/log/join-to-domain.log
lsb_release -a &>> /var/log/join-to-domain.log
echo " " &>> /var/log/join-to-domain.log

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

# Синхронизация времени с контроллером домена
chrony_conf()
{
  v_date_time=$(date '+%d-%m-%y_%H-%M-%S')
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
then
     echo
     echo -e ${RED}' Домен '${NC}${GREEN}$v_domain${NC}${RED}' недоступен! Проверьте настройки сети.'${NC}
     echo -e ' Домен '$v_domain' недоступен! Проверьте настройки сети.' &>> /var/log/join-to-domain.log
     exit 1
  else echo -e ' Домен '${GREEN}$v_domain${NC}' доступен!'
       echo -e ' Домен '$v_domain' доступен!' &>> /var/log/join-to-domain.log
fi
}

# Функция проверки имени ПК
checkname()
{
	if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9\-])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
	then
	  check_name="true"
	fi
	if [ "$v_name_pc" != "$1" ] && [ "$check_name" = "true" ];
	  then true
		else echo -e "\n ${RED}Ошибка! Недопустимое имя ПК!${NC}"
		     echo -e " Ошибка! Недопустимое имя ПК!" &>> /var/log/join-to-domain.log
		exit 1
	fi
}

# Функция проверки прохождения аутентификации и существования ПК в домене
check_domain_name()
{
	#$1 - v_admin
	#$2 - v_domain
	#$3 - v_name_pc
	#$4 - v_pass_admin
rm -f /tmp/join_check.txt
check=$(adcli show-computer -U $1 --domain=$2 $3 --stdin-password <<< $4 &> /tmp/join_check.txt)
v_check=$(cat /tmp/join_check.txt)
echo " Проверка аутентификации в домене:"  &>> /var/log/join-to-domain.log
cat /tmp/join_check.txt &>> /var/log/join-to-domain.log
if grep -Pq "sAMAccountName" <<< "$v_check";
    then
    if [[ -n "$force" ]]; then
            echo ""
            echo -e ${YEL}" В домене уже существует компьютер "${NC}${GREEN}$3${NC}
            echo -e " Предупреждение! В домене уже существует компьютер "$3 &>> /var/log/join-to-domain.log
            if [[ -n "$v_ou" ]]; then
                unset v_ou
            fi
    elif [[ -n "$v_pass_admin_gui" ]]; then
                zenity --warning --text 'В домене уже существует компьютер '$v_name_pc' \nудалите данную учетную запись компьютера в домене или укажите иное имя ПК.' \
                --no-wrap &> /dev/null
                echo -e " Ошибка! В домене уже существует компьютер "$v_name_pc &>> /var/log/join-to-domain.log
                f_create_form &> /dev/null
    else
		echo ""
		echo -e ${RED}" В домене уже существует компьютер "${NC}${GREEN}$3${NC}
		echo -e " Ошибка! В домене уже существует компьютер "$3 &>> /var/log/join-to-domain.log
		echo -e ${RED}" Удалите данную учетную запись компьютера в домене или укажите иное имя ПК."${NC}
		echo -e " Удалите данную учетную запись компьютера в домене или укажите иное имя ПК." &>> /var/log/join-to-domain.log
		echo
		exit 1;
    fi
fi
if grep -Pq "Couldn't authenticate" <<< "$v_check";
    then
        if [[ -n "$v_pass_admin_gui" ]];
	    then
	        zenity --warning --text 'Неверное имя администратора домена или пароль!' \
           	--no-wrap &> /dev/null
           	echo -e " Ошибка! Неверное имя администратора домена или пароль! " &>> /var/log/join-to-domain.log
            f_create_form &> /dev/null
 	    else
	        echo ""
	        echo -e ${RED}" Неверное имя администратора домена или пароль! "${NC}
	        echo -e " Ошибка! Неверное имя администратора домена или пароль! " &>> /var/log/join-to-domain.log
	        echo
	        exit 1;
	fi
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


# Функция создания файла krb5.conf, определение имени домена и контроллера
f_create_krb5()
{

dc=$(adcli info $v_domain|grep "domain-controller ="| awk '{print $3}')
# Короткое имя домена
v_short_domen=$(cut -d'.' -f2 <<< "$dc")
v_short_dc=$(cut -d'.' -f1 <<< "$dc") # Короткое имя контроллера домена
# Короткое имя домена в верхнем регистре
v_BIG_SHORT_DOMEN=$(tr [:lower:] [:upper:] <<< "$v_short_domen")
# Полное имя домена в верхнем регистре
v_BIG_DOMAIN=$(tr [:lower:] [:upper:] <<< "$v_domain")
domainname=$(domainname -d)
cp /etc/krb5.conf /etc/krb5.conf.$v_date_time
echo -e ' ' >> /var/log/join-to-domain.log
echo -e 'Информация о домене:' >> /var/log/join-to-domain.log
adcli info $v_domain &>> /var/log/join-to-domain.log
echo -e ' ' >> /var/log/join-to-domain.log

if [[ -z "$v_kdc" ]]; then
	str_pdc=" pdc " # Основной DC
	str_closest=" closest " # Ближайший DC
	str_writable=" writable "
	string=$(adcli info $v_domain | grep "domain-controllers =" | sed s'/domain-controllers =//g')
	IFS='  ' read -r -a array <<< "$string"
	for i in "${array[@]}"
	do
		full_str=$(adcli info --domain-controller=$i | grep "domain-controller-flags =")
		if [[ "$full_str" == *"$str_pdc"* ]]; then
			krb5_kdc1="kdc = $i"
			kdc1=$i
		fi
		if [ "$full_str" == *"$str_closest"* ] && [ "$full_str" != *"$str_pdc"* ]; then
			krb5_kdc2="kdc = $i"
		fi
	done
	else
	kdc1=$v_kdc
	krb5_kdc1="kdc = $v_kdc"
fi

echo -e 'includedir /etc/krb5.conf.d/

[logging]
    default = FILE:/var/log/krb5libs.log
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmind.log

[libdefaults]
    dns_lookup_realm = false  # Отключить поиск kerberos-имени домена через DNS
    dns_lookup_kdc = true  # Включить поиск kerberos-настроек домена через DNS
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
	then zenity --warning --text 'Домен '$v_domain' недоступен! Проверьте настройки сети.' --no-wrap &> /dev/null
	f_create_form &> /dev/null
    fi

    # Проверка имени компьютера
    if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9\-])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
	then
	    echo " Имя ПК: $v_name_pc"
	else
	    zenity --warning --text "Ошибка! Недопустимое имя ПК!" &> /dev/null
	    echo  "  Ошибка! Недопустимое имя ПК!" &>> /var/log/join-to-domain.log
	    f_create_form &> /dev/null
    fi

    echo " Имя ПК: $v_name_pc"

    # Вызов функции формирования krb5.conf
    f_create_krb5

    if [ "$v_name_pc" != "$v_short_dc" ];
    then
        echo " Имя ПК: $v_name_pc"
    else
	    zenity --warning --text 'Ошибка! Имя ПК ('$v_name_pc') не должно совпадать с именем контроллера домена!' --no-wrap &> /dev/null
	    echo -e '  Ошибка! Имя ПК ('$v_name_pc') не должно совпадать с именем контроллера домена!' &>> /var/log/join-to-domain.log
	    f_create_form &> /dev/null
    fi

    # ----- Проверка существования ПК в домене и проверка аутентификации -----
    check_domain_name $v_admin $v_domain $v_name_pc $v_pass_admin_gui
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
    if [[ -n "$force" ]]; then
        echo ' Применен ключ -f, учетная запись ПК не будет удалена с контроллера домена!'
    fi
    myAsk
    v_delete_host=`hostname -a`
    v_domain=`hostname -d`

    if [ -n "$gui" ]
		then
		data_exit=( $(zenity --forms --separator=" " \
			--title="Вывод из домена" \
			--text="Удаление учетной записи ПК из домена." \
			--add-entry="Имя администратора домена:" \
			--add-password="Пароль администратора:" \
			--ok-label="OK" \
			) )

			# Если zenity NO, то выход из скрипта
			if [ $? -eq 1 ]; then
				exit
			fi

			v_leave_admin=${data_exit[0]}
			v_pass_admin_gui=${data_exit[1]}
			adcli delete-computer -U $v_leave_admin --domain=$v_domain  $v_delete_host --stdin-password <<< $v_pass_admin_gui &>> /var/log/join-to-domain.log
			if [ $? -ne 0 ]; then
				zenity --error \
                   --title="Вывод из домен Windwos/Samba" \
                   --text="Ошибка удаления учётной записи ПК из домена. \nВозможно логин или пароль введен неверно.\nсм.  /var/log/join-to-domain.log" \
                   --no-wrap &> /dev/null
				exit 1;
			fi
		else
			echo ""
            if [[ -z "$force" ]]; then
			echo ' Удаление учетной записи ПК из домена.'
			read -p ' Введите имя контроллера домена или для продолжения нажмите ENTER: ' v_kdc
			read -p ' Введите имя администратора домена: ' v_leave_admin
			if [ -n "$v_kdc" ]
				then
				adcli delete-computer -U $v_leave_admin -S $v_kdc --domain=$v_domain  $v_delete_host &>> /var/log/join-to-domain.log
			else
				adcli delete-computer -U $v_leave_admin --domain=$v_domain  $v_delete_host &>> /var/log/join-to-domain.log
			fi
			if [ $? -ne 0 ]; then
				echo -e " ${RED}Ошибка вывода из домена, см. /var/log/join-to-domain.log${NC}"
				echo -e " ${RED}Возможно логин или пароль введен неверно.${NC}"
				echo -e " Ошибка вывода из домена, см.  /var/log/join-to-domain.log" &>> /var/log/join-to-domain.log
				exit 1;
			fi
            fi
	fi
    # backup smb.conf
    cp /etc/samba/smb.conf /etc/samba/smb.conf.$v_date_time
    realm leave -v --client-software=sssd &>> /var/log/join-to-domain.log
    realm leave -v --client-software=winbind &>> /var/log/join-to-domain.log
    sss_cache -E &>> /var/log/join-to-domain.log
    kdestroy &>> /var/log/join-to-domain.log

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


rpm_install_error () {
if [ $? -ne 0 ];
	then echo -e "   ${RED} Ошибка установки необходимого RPM-пакета, см. /var/log/join-to-domain.log${NC}"
		exit 1;
	else echo -e "    Пакет $i успешно установлен! " | tee -a /var/log/join-to-domain.log
fi
}

check_rpm_install(){
declare -a rpm_array=( "realmd" "sssd" "oddjob" "oddjob-mkhomedir" "adcli" "samba-common" "samba-common-tools" "krb5-workstation" "samba-winbind-clients" )
for i in "${rpm_array[@]}"
do
  rpm_result=$(rpm -q $i)
  if [[ $? -eq "1" ]];
	then
	echo -e "    Пакет $i не установлен! Выполняю установку $i" | tee -a /var/log/join-to-domain.log
	if [ -f "/usr/bin/dnf" ]; then
		dnf install $i -y &>> /var/log/join-to-domain.log
		rpm_install_error
	else yum install $i -y &>> /var/log/join-to-domain.log
		rpm_install_error
	fi
  fi
done
}

# Проверка на realm list
result_realm=$(realm list)
if [ -z "$result_realm" ]
   then echo -e '\n Ввод РЕД ОС в домен Windows(2008/2012/2016/2019/2022), SAMBA, IPA \n'
   echo ' Этот компьютер не в домене!' | tee -a /var/log/join-to-domain.log
   myAsk
   f_choce_pill
   elif [ -n "$gui" ]
   then (
   zenity --question --title="Компьютер в домене!" \
          --text="Компьютер в домене! \nВывести компьютер из домена?" \
          --ok-label="Да" \
          --cancel-label="Отмена" \
          --no-wrap &> /dev/null
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
                  --width=300 --height=140 --progress --pulsate --auto-close --auto-kill &> /dev/null
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
            exit 1;
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
		then break;
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


# ---------- Ввод данных в терминале ----------
# Если отсутствуют входные параметры скрипта
if [[ -z "$v_domain"  &&  -z "$v_name_pc"  &&  -z "$v_admin" && -z "$gui" &&  -z "$v_ou" ]];
  then

    v_search_domain=$(cat /etc/resolv.conf | grep "search " | awk '{print $2}')
    if  [[ -z "$v_search_domain" ]]; then
		echo -e ' Для ввода РЕД ОС в домен Windows/SAMBA, введите имя домена.\n Пример: example.com\n'
		read -p ' Имя вашего домена: ' v_domain
    else
		echo
		echo -e ' Имя домена ['${GREEN}$v_search_domain${NC}']';
		read -p ' Для подтверждения нажмите ENTER или введите имя домена вручную: ' v_domain
		echo
		if [[ -z "$v_domain" ]]; then
			v_domain=$v_search_domain
		fi
    fi

    echo ' Введите имя ПК. Пример: client1'
    dc=$(adcli info $v_domain 2>/dev/null | grep "domain-controller ="| awk '{print $3}')
    v_short_dc=$(cut -d'.' -f1 <<< "$dc") # Короткое имя контроллера
	while true; do
	  read -p ' Имя ПК: ' v_name_pc
	  if grep -Pq '(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9\-])?)+[a-zA-Z0-9]$)' <<< $v_name_pc
	  then
	     check_name="true";
	  fi
	  if [ "$v_name_pc" != "$v_short_dc" ] && [ "$check_name" = "true" ];
	  then break;
		else echo -e "\n ${RED}Ошибка! Недопустимое имя ПК!${NC}"
			 echo -e " Ошибка! Недопустимое имя ПК!" &>> /var/log/join-to-domain.log
      fi
	done

	read -p ' Имя администратора домена: ' v_admin
	read -p ' Имя подразделения ПК(OU=MyComputers) без кавычек или для продолжения нажмите ENTER:' v_ou
    # Проверка вводимых данных
    if [[ -z "$v_admin" ]]
       then echo -e " ${RED}Ошибка! Введите имя администратора домена.${NC}"
            echo -e " Ошибка. Введите имя администратора домена." &>> /var/log/join-to-domain.log
        exit 1;
    fi
  # иначае если имеются входные параметры
  else
    if [[ -z "$v_admin" ]]
        then echo -e " ${RED}Ошибка! Введите имя администратора домена. Используйте параметр -u${NC}"
        exit 1;
    fi
    if [[ -z "$v_name_pc" ]]
        then echo -e " ${RED}Ошибка! Введите имя ПК. Используйте параметр -n${NC}"
        exit 1;
    fi
    if [[ -z "$v_domain" ]]
        then echo -e " ${RED}Ошибка! Введите имя домена. Используйте параметр -d${NC}"
        exit 1;
    fi
    dc=$(adcli info $v_domain|grep "domain-controller ="| awk '{print $3}')
    v_short_dc=$(cut -d'.' -f1 <<< "$dc") # Короткое имя контроллера
    checkname "$v_short_dc" || exit;
fi

# Параметр для добавления ПК в определенную организационную единицу (подразделение)
if [[ ! -z "$v_ou" ]];
    then
     IFS='. ' read -r -a array <<< $v_domain
     for el in "${array[@]}"; do
       as+=",DC=""$el"
     done
     v_ou_net_ads='createcomputer='$v_ou$as
     v_ou_realm_join='--computer-ou='$v_ou$as
fi

# Настройка nsswitch.conf
v_date_time=$(date '+%d-%m-%y_%H:%M:%S')
cp /etc/authselect/user-nsswitch.conf /etc/authselect/user-nsswitch.conf.$v_date_time &> /dev/null
authselect select sssd --force &> /dev/null
sed -i 's/\bhosts:.*/hosts:      files dns resolve [!UNAVAIL=return] myhostname mdns4_minimal/g' /etc/authselect/user-nsswitch.conf
authselect apply-changes &> /dev/null

# Проверка доступности домена
f_realm_discover

# Вызов функции формирования krb5.conf
if [[ -z "$v_pass_admin_gui" ]];
then
    f_create_krb5
fi

# realm join console
if [[ -z "$v_pass_admin_gui" &&  -z "$v_pass_admin" ]];
then
  read -sp  " Введите пароль администратора домена: " v_pass_admin && echo
  # Проверка существования имени ПК в домене
  check_domain_name $v_admin $v_domain $v_name_pc $v_pass_admin
fi

if [[ -n "$v_pass_admin" ]];
then
  check_domain_name $v_admin $v_domain $v_name_pc $v_pass_admin
fi

# Вызов функции диалога
if [[ -z "$yes" ]]
then
    myAsk
fi


echo -e '' >> /var/log/join-to-domain.log

# Установка дополнительных пакетов
if [[ -n "$v_pass_admin_gui" ]];
then
(
	echo -e ' 1) Проверка наличия установленных RPM-пакетов (GUI)' | tee -a /var/log/join-to-domain.log	
	check_rpm_install
) |
   zenity  --title="Ввод в домен!" --text="Установка необходимых пакетов..." --width=300 --height=140 --progress --pulsate --auto-close --auto-kill
   else
   echo -e ' 1) Проверка наличия установленных RPM-пакетов' | tee -a /var/log/join-to-domain.log
   check_rpm_install
fi

echo -e ' 2) Изменение имени ПК' | tee -a /var/log/join-to-domain.log
hostnamectl set-hostname $v_name_pc.$v_domain
echo -e '    Новое имя ПК: '`hostname` | tee -a /var/log/join-to-domain.log

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


os_name=`cat /etc/os-release | grep ^"NAME=" | awk -F= '{print $2}' | sed 's/\"//g'`
os_version=`cat /etc/os-release | grep ^"VERSION_ID=" | awk -F= '{print $2}' | sed 's/\"//g'`

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
echo -e ' 5) Ввод в домен (winbind) ...' | tee -a /var/log/join-to-domain.log

realm join -vvv -U $v_admin --client-software=winbind $v_domain "$v_ou_realm_join" --os-name="$os_name" --os-version="$os_version" <<< $v_pass_admin &>> /var/log/join-to-domain.log
if [ $? -ne 0 ];
  then echo -e "    ${RED}Ошибка ввода в домен, см. /var/log/join-to-domain.log${NC}"
       echo -e "    Ошибка ввода в домен, см. /var/log/join-to-domain.log" &>> /var/log/join-to-domain.log
       exit 1;
fi

echo -e ' 6) Выполняется authselect' | tee -a /var/log/join-to-domain.log
authselect select winbind with-mkhomedir with-krb5 --force &>> /var/log/join-to-domain.log
authselect enable-feature with-mkhomedir &>> /var/log/join-to-domain.log

# samba config log
echo -e ' 7) Настройка samba' | tee -a /var/log/join-to-domain.log

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

echo -e ' 8) Тест конфигурации samba' | tee -a /var/log/join-to-domain.log
echo -e "\n" | testparm &>> /var/log/join-to-domain.log

# Настройка limits
cp /etc/security/limits.conf /etc/security/limits.conf.$v_date_time
echo -e '*     -  nofile  16384
root  -  nofile  16384' > /etc/security/limits.conf

# join to domain
join_to_domain() {
    if [[ $wg == "" ]] ; then
      echo -e ' 9) Выполняю net ads join' | tee -a /var/log/join-to-domain.log
      net ads join -S "${kdc1}" -U "${v_admin}%${v_pass_admin}" &>> /var/log/join-to-domain.log
      else
      echo -e ' 9) Выполняю net ads join' | tee -a /var/log/join-to-domain.log
      net ads join -S "${kdc1}" -U "${v_admin}%${v_pass_admin}" -W "$wg" &>> /var/log/join-to-domain.log
    fi

    if [[ $? != 0 ]]; then
        return 1
    fi
}
join_to_domain

# Запуск сервисов
echo -e ' 10) Запуск сервиса winbind' | tee -a /var/log/join-to-domain.log
systemctl enable winbind --now &>> /var/log/join-to-domain.log
echo -e ' 11) Запуск сервиса smb' | tee -a /var/log/join-to-domain.log
systemctl enable smb --now &>> /var/log/join-to-domain.log

# Настройка /etc/security/pam_winbind.conf
settings_pam_winbind
echo -e ' Внимание! Для вступления изменений в силу требуется перезагрузка компьютера!' | tee -a /var/log/join-to-domain.log
exit;
fi

#---------------------------End winbind----------------------------------------------#


# ***** realm join in GUI *****
if [[ -n "$v_pass_admin_gui" ]];
then
  echo -e ' 5) Ввод в домен (GUI)...' | tee -a /var/log/join-to-domain.log
(
    join_count=1
    realm join -vvv -U $v_admin $kdc1 --os-name="$os_name" --os-version="$os_version" <<< $v_pass_admin_gui &>> /var/log/join-to-domain.log
    code_err=$?
    while [ $code_err -ne 0 ]; do
       join_count=$((join_count+1))
       echo -e ' Ввод в домен. Попытка №'$join_count | tee -a /var/log/join-to-domain.log
       realm join -vvv -U $v_admin $kdc1 --os-name="$os_name" --os-version="$os_version" <<< $v_pass_admin_gui &>> /var/log/join-to-domain.log
       code_err=$?
       if [ "$join_count" -gt 3 ]; then
         touch /tmp/realm-join-error
         break
       fi
     done
) |
zenity  --title="Ввод в домен!" \
        --text="Выполняю ввод в домен..." \
        --width=300 --height=140 --progress --pulsate --auto-close --auto-kill &> /dev/null
fi

# Если файл ошибки(realm join...) существует, то выводим ошибку и выходим из сценария.
if [ -f "/tmp/realm-join-error" ]
then
    zenity --error \
           --title="Ввод в домен" \
           --text="Ошибка ввода в домен, см. /var/log/join-to-domain.log" \
           --no-wrap &> /dev/null
    rm -rf /tmp/realm-join-error
    exit 1;
fi

# ***** realm join in console *****
if [[ -z "$v_pass_admin_gui" ]]
then
  join_count=1
  echo -e ' 5) Ввод в домен ... ' | tee -a /var/log/join-to-domain.log

  if [[ ! -z "$v_ou" ]]; then
     realm join -vvv -U "$v_admin" "$kdc1" "$v_ou_realm_join" --os-name="$os_name" --os-version="$os_version" <<< $v_pass_admin &>> /var/log/join-to-domain.log
  else  realm join -vvv -U "$v_admin" "$kdc1" --os-name="$os_name" --os-version="$os_version" <<< $v_pass_admin &>> /var/log/join-to-domain.log
  fi
  code_err=$?
  while [ $code_err -ne 0 ]; do
    join_count=$((join_count+1))
    echo -e ' Ввод в домен. Попытка №'$join_count | tee -a /var/log/join-to-domain.log
    if [[ ! -z "$v_ou" ]]; then
       realm join -vvv -U "$v_admin" "$kdc1" "$v_ou_realm_join" --os-name="$os_name" --os-version="$os_version" <<< $v_pass_admin &>> /var/log/join-to-domain.log
    else  realm join -vvv -U "$v_admin" "$kdc1" --os-name="$os_name" --os-version="$os_version" <<< $v_pass_admin &>> /var/log/join-to-domain.log
    fi
    code_err=$?
    if [ "$join_count" -gt 3 ]; then
        echo -e ${RED}'    Ошибка ввода в домен, см. /var/log/join-to-domain.log'${NC}
        echo -e '    Ошибка ввода в домен, см. /var/log/join-to-domain.log' &>> /var/log/join-to-domain.log
        exit 1;
    fi
  done
fi


# Настройка sssd.conf
echo -e ' 6) Настройка sssd' | tee -a /var/log/join-to-domain.log
cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf.$v_date_time &>> /var/log/join-to-domain.log
if [[ -n "$v_slc" ]]; then
   ulc="False"
   else ulc="Preserving"         
fi
echo -e '[sssd]
domains = '$(domainname -d)'
config_file_version = 2
services = nss, pam

[domain/'$(domainname -d)']
ad_domain = '$(domainname -d)'
ad_server = '$kdc1'
krb5_realm = '$v_BIG_DOMAIN'
case_sensitive = '$ulc'
realmd_tags = manages-system joined-with-samba

# Кэширование аутентификационных данных, необходимо при недоступности домена
cache_credentials = True

id_provider = ad
access_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
ad_gpo_access_control = disabled

# Включает/Отключает режим полных имён пользователей при входе
use_fully_qualified_names = False

# Определение домашнего каталога для доменных пользователей
fallback_homedir = /home/%u@%d

# Параметр access_provider = simple Определяет список доступа на основе имен пользователей или групп.
#access_provider = simple
#simple_allow_users = user1@example.com, user2@example.com
#simple_allow_groups = group@example.com

# Включает/Отключает перечисление всех записей домена, операция(id или getent) может занимать длительное время при enumerate = true в больших инфраструктурах
enumerate = false

# Параметр ignore_group_members может ускорить авторизацию в домене если домен имеет большое количество пользователей, групп и вложенных OU
# Если установлено значение TRUE, то атрибут членства в группе не запрашивается с сервера ldap и не обрабатывается вызовов поиска группы.
# ignore_group_members = True

# Поиск ссылок может привести к снижению производительности в средах, которые их интенсивно используют.
# true - не рекомендуется для больших инфраструктур. Отключаем этот поиск.
ldap_referrals = false

# Включает/Отключает динамические обновления DNS, если в статусе sssd ошибка "TSIG error with server: tsig verify failure", то установите dyndns_update = false
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
  zenity --width=300 --height=140 --progress --title="Ввод в домен" --text="Настройка сервиса sssd..." --pulsate --auto-close &> /dev/null
fi


if [[ -z "$v_pass_admin_gui" ]];
then
    authconfig --enablemkhomedir --enablesssdauth --updateall &>> /var/log/join-to-domain.log
fi

# Настройка limits
echo -e ' 7) Настройка limits' | tee -a /var/log/join-to-domain.log
cp /etc/security/limits.conf /etc/security/limits.conf.$v_date_time
echo -e '*     -  nofile  16384
root  -  nofile  16384' > /etc/security/limits.conf


# samba config log
echo -e ' 8) Настройка samba' | tee -a /var/log/join-to-domain.log

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
    winbind use default domain = No
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
echo -e ' 9) Ввод samba в домен (GUI)...' | tee -a /var/log/join-to-domain.log
(
    net ads join -S "$kdc1" -U $v_admin%$v_pass_admin_gui -D $v_domain &>> /var/log/join-to-domain.log
    if [ "$?" = 1 ]; then
        touch /tmp/net-ads-join-error
    fi
sleep 2
) |
zenity  --title="Ввод в домен!" \
        --text="Выполняю команду net ads join..." \
        --width=300 --height=140 --progress --pulsate --auto-close --auto-kill &> /dev/null
fi

if [ -f "/tmp/net-ads-join-error" ]
then
    zenity --error \
           --title="Ввод в домен" \
           --text="Ошибка ввода в домен, см. /var/log/join-to-domain.log" \
           --no-wrap &> /dev/null
rm -rf /tmp/net-ads-join-error
exit 1;
fi

# net ads in console
if [[ -z "$v_pass_admin_gui" ]]
then
	echo -e ' 9) Ввод samba в домен...' | tee -a /var/log/join-to-domain.log
    net ads join -S "$kdc1" -U $v_admin%$v_pass_admin -D $v_domain &>> /var/log/join-to-domain.log
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
systemctl disable systemd-timesyncd &> /dev/null
systemctl stop systemd-timesyncd &> /dev/null

exit;
