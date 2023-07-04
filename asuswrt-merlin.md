# مقدمه
در این آموزش نحوه بیلد کردن این ابزار رو برای روترهای ایسوس توضیح میدم  
# چرا؟
با استفاده از سرور ایران کیفیت خوبی نمیگرفتم اما به صورت مستقیم کیفیت کانکشن به مراتب بهتر بود  
# مشکل؟
یه شبکه خانگی را تصور کنید، دستگاه های مختلفی در این شبکه هستند، از جمله لپ تاپ، گوشی، اسمارت تی وی و دیگر دیوایس ها  
این یک ابزار واسط میباشد که میان کلاینت شما و سرور قرار میگیرد، بنابراین قبل از استارت کلاینت باید تانل را اجرا کنید که همین عمل یک لایه پیچیدگی ایجاد میکند و حتی ممکن است اجرای آن روی دستگاه هایی از جمله اسمارت تی وی تقریبا غیرممکن باشد
# ایده؟
به جای استارت کردن تانل روی دستگاه های مختلف یکبار روی روتر اجرا میکنم و به این صورت روتر مانند سرور ایران عمل میکند
# پیشنیازها
- روتر ایسوس با فریمور بروز
- فلش مموری
- آشنایی نسبی با ترمینال
- صبر به مقادیر خیلی زیاد
# روتر تست شده
[**Asus ROG Rapture GT-AX6000**](https://rog.asus.com/us/networking/rog-rapture-gt-ax6000-model)
# فعال کردن ssh
به صورت پیش فرض فعال نیست و باید از تنظیمات فعالش کنید
# Asuswrt-Merlin
ابتدا باید این فریمور کاستوم رو روی روتر نصب کنید  
وارد سایت رسمیش بشید  
[**Asuswrt-Merlin**](https://www.asuswrt-merlin.net)  
مدل روتر خودتون رو پیدا کنید و آخرین ورژن پایدار ریلیز شده رو دانلود و نصب کنید  
روند نصبش اصلا سخت نیست و از طریق پنل مدیریت وب روتر انجام میشه  
فایل فشرده دانلود شده رو اکسترکت کنید  
اکستنشن فایل فریمور  
kgtb  
وارد مسیر  
Administration > Firmware Upgrade  
بشید و از گزینه آپلود فایل رو انتخاب کنید، صبر کنید نصب تمام شود
# Entware
خوب ما قراره این ابزار رو روی خود روتر بیلد کنیم!! پس به کلی ابزار نیاز داریم، خبر بد اینه که ابزارهای روتر حتی با فریمور کاستوم مرلین به شدت محدود هست  
اما خبر خوب  
[**Entware/Entware**](https://github.com/Entware/Entware)  
هست که یه رپو خیلی خفنه شامل کلی ابزار کاربردی برای دستگاه های امبدد  
برای نصبش شما به فلش مموری نیاز دارید که حتما هم باید فرمت  
ext4  
داشته باشه  
# چطوری نصبش کنیم؟
فلش مموری رو به روتر وصل کنید و این دستور را وارد کنید  
```bash
# Asuswrt-Merlin Terminal Menu
amtm
```
یک منو برای شما باز میشود، دستور زیر را تایپ و سپس اینتر را بزنید تا ستاپ نصب لانچ شود  
```
ep
```
وارد یک ستاپ میشوید که باید به چند سوال ساده پاسخ دهید  
این ستاپ بصورت آنلاین پکیج ها را دریافت میکند، ممکنه به همین علت وسط کار متوقف بشید (احتمالا مکانیزیم سعی مجدد در صورت خطا نداره!)  
اگر این حالت پیش اومد ستاپ رو کنسل کنید و ابتدا لینک ایجاد شده را پاک کنید  
```
rm /tmp/opt
```
حالا ستاپ نصب رو دوباره استارت کنید  
در صورت نصب موفق دستور زیر باید محتوای فایل را چاپ کند  
```
# /opt/etc/passwd -> /etc/passwd
cat /opt/etc/passwd
```
وارد دایرکتوری زیر بشید
```
cd /opt/home
``` 
# نصب ابزارهای مورد نیاز
خوب شما الان یک پکیج منیجر دارید با نام  
opkg  
ابزارهای مورد نیاز را نصب کنید  
```bash
opkg install tar
opkg install openssl-util
opkg install curl
opkg install git
opkg install gcc
opkg install screen
```
# Nim compiler
یک ابزار دیگه مونده برای نصب  
رپوی بیلد این کامپایلر در اینجا موجود هست  
[**nim-lang/nightlies**](https://github.com/nim-lang/nightlies/releases)  
```bash
wget https://github.com/nim-lang/nightlies/releases/download/latest-version-1-6/linux_arm64.tar.xz
/opt/bin/tar -xvf linux_arm64.tar.xz
mv nim-x.x.x nim
```
برای اجرای کامپایلر باید دایرکتوری شامل فایل اجرایی اون رو به متغییر سیستمی آدرس اضافه کنید  
```bash
export PATH="$PATH:/opt/home/nim/bin"
```
# Github ssh key
برای کلون کردن پروژه ابتدا باید یک کلید بسازید  
```bash
dropbearkey -t rsa -f github
```
هنگام ساخت کلید عمومی رو چاپ میکنه که باید کپی کنید و به گیت هاب اضافه کنید
# Clone repo
پروژه رو کلون کنید و وارد اون بشید  
```bash
GIT_SSH_COMMAND='ssh -i /opt/home/github -o IdentitiesOnly=yes' git clone git@github.com:radkesvat/FakeTlsTunnel.git
cd FakeTlsTunnel
```

# Build
میرسیم به غول مرحله آخر یعنی بیلد کردن ولی قبل از هر چیزی باید یک سوئیچ به تسک بیلد اضافه کنید  
```bash
nano config.nims
# task build_server:
# switch("define", "nimNoGetRandom")
```
حالا میتونید بیلد کنید
```bash
nim build
```
اگر مراحل رو درست انجام داده باشید بیلد باید بدون خطا انجام بشه و سپس در فولدر
dist  
فایل اجرا آماده استفاده میشه
# Screen
برای اینکه بتونید تونل رو اجرا کنید ولی از ترمینال خارج بشید  
```bash
nano /opt/ftt
```
محتوای زیر در فایل قرار بدید
```bash
#!/bin/sh

SESSION_NAME="FTT"
FTT="/opt/home/FakeTlsTunnel/dist/FTT"
FROM_PORT="443"
SERVER="88.1.2.3"
TO_PORT="443"
SNI="github.com"
PASS="123ab"

toggle() {
  SESSION=$(screen -ls | grep $SESSION_NAME)
  if [ -z "$SESSION" ]
  then
    echo "Starting $SESSION_NAME"
    screen -dmS $SESSION_NAME $0 start
  else
    echo "Terminate $SESSION_NAME"
    $0 stop
  fi
}

start() {
  $FTT --tunnel --lport:$FROM_PORT --toip:$SERVER --toport:$TO_PORT --sni:$SNI --password:$PASS
}

stop () {
  screen -S $SESSION_NAME -X quit
}

if [ -z "$1" ]
then
  toggle
elif [[ "$1" == "start" ]]
then
  start
elif [[ "$1" == "stop" ]]
then
  stop
fi
```
مقادیر متغییرها رو بر اساس کانفیگ خودتون تغییر بدید و سپس فایل رو ذخیره کنید
```bash
chmod +x /opt/ftt
```
حالا اسکریپت قابل اجرا هست  
با وارد کردن دستور
```
/opt/ftt
```
تانل اجرا میشود و برای توقف هم دوباره همین دستور را اجرا کنید
# سخن پایانی
امیدوارم از این آموزش لذت برده باشید  
موارد خیلی زیاد بودند و واقعا نمیشد مفصل توضیح داد  
مطالبی که مطالعه کردید خلاصه و چکیده یک هفته سر و کله زدن اینجانب  
[**Saeed-Pooyanfar**](http://github.com/Saeed-Pooyanfar)  
با روتر و ابزارهای مختلف بود  
در آخر تشکر میکنم از توسعه دهنده اصلی  
[**radkesvat**](https://github.com/radkesvat)  
بابت این ابزار بسیار کاربردی  
به امید رفع محدودیت ها و دسترسی همیشگی به اینترنت آزاد
