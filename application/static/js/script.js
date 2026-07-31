// ================================
// LIVE CLOCK
// ================================

function updateClock() {

    const now = new Date();

    const options = {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    };

    const clock = document.getElementById("clock");

    if(clock){
        clock.innerHTML = now.toLocaleTimeString([], options);
    }

}

setInterval(updateClock,1000);

updateClock();


// ================================
// COUNTER ANIMATION
// ================================

function animateCounter(id,target,speed){

    let value = 0;

    const counter = document.getElementById(id);

    if(!counter) return;

    const timer = setInterval(()=>{

        value++;

        counter.innerHTML=value;

        if(value>=target){

            clearInterval(timer);

        }

    },speed);

}

animateCounter("users",500,5);
animateCounter("servers",8,150);
animateCounter("uptime",99,30);
animateCounter("requests",1500,1);


// ================================
// CARD HOVER EFFECT
// ================================

const cards=document.querySelectorAll(".box");

cards.forEach(card=>{

    card.addEventListener("mouseenter",()=>{

        card.style.transform="translateY(-10px) scale(1.03)";

    });

    card.addEventListener("mouseleave",()=>{

        card.style.transform="translateY(0px) scale(1)";

    });

});


// ================================
// RANDOM STATUS COLOR
// ================================

const status=document.querySelector(".status");

setInterval(()=>{

    status.style.boxShadow="0 0 20px rgba(34,197,94,.6)";

    setTimeout(()=>{

        status.style.boxShadow="none";

    },600);

},2500);


// ================================
// PAGE LOADED
// ================================

console.log("Secure Access Portal Loaded Successfully");