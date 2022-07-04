import React from "react";
import ReactDOM from "react-dom/client";
import "./index.css";
import get_clues from "./spell.js"

function unique(A) {
    return A.reduce((A, x) => { if(x != A.at(-1)) { A.push(x); } return A; }, []);
}

const root = ReactDOM.createRoot(document.getElementById("root"));

function Message(props) {
    return <div style={{textAlign: 'center', fontSize: '16pt'}}>{props.children}</div>
}

root.render(<Message>Loading . . .</Message>);
fetch("https://joylrnxhyj.execute-api.us-east-1.amazonaws.com/gamedata")
.then(resp => resp.json())
.then(data => {
    console.log("got game data for " + data.today.displayDate);

    const game = { data };
    game.special = data.today.centerLetter;
    game.words = data.today.answers.sort((a,b) =>
        a.slice(0,2) == b.slice(0,2) ? a.length - b.length : a < b ? -1 : 1);
    game.firsts = unique(game.words.map(w => w.slice(0,1)));
    game.seconds = unique(game.words.map(w => w.slice(0,2)));
    // console.log(game.special, game.words, game.firsts, game.seconds);
    root.render(<App game={game} />);
})
.catch(err => {
    console.error(err);
    root.render(<Message>ERROR: Couldn't fetch game data. {err.message}.</Message>);
});

class App extends React.Component {
    constructor(props) {
        super(props);
        this.game = props.game;
        this.state = { clues: {}, done: {}, letters: [''] };
        for(let w of this.game.words) this.state.clues[w] = '???';
        get_clues(this.game.data.today.answers, (word, clue) => 
            this.setState(state => ({ clues: { ...state.clues, [word]: clue } }))
        );
    }

    setLetters = e => this.setState({letters: e.target.value});
    setDone = e => this.setState(state => {
        let elm = e.target;
        while(elm && elm.tagName != 'LI') elm = elm.parentElement;
        const word = elm?.attributes.word?.value;
        if(!word) { return null; } else { e.preventDefault(); }
        return { done: { ...state.done, [word]: !state.done[word] }};
    });

    render() {
        const game = this.game;
        const done = this.state.done;
        const clues = this.state.clues;
        const letters = this.state.letters;
        
        let len = 0;
        const items = [];
        game.words.filter(w => w.slice(0,2) == letters).forEach(word => {
            if(word.length != len) {
                len = word.length;
                items.push(<div key={len} className='len-header'>{len}</div>);
            }
            items.push(
                <li key={word} word={word} onClick={this.setDone}>
                    {!done[word] ? clues[word] :
                        <>
                            <span key='done' className='done'>{clues[word]}</span>
                            <span key='answer' className='answer'>{word}</span>
                        </>
                    }
                </li>
            );
        });

        return (
            <div id='content'>
                <div id='date'>{game.data.today.displayDate}</div>
                <div id='top-buttons'>
                    {game.firsts.map(l => {
                        let classes = 'top-button';
                        if(l == letters[0]) classes += ' top-button-selected';
                        if(l == game.special) classes += ' top-button-special';
                        if(game.words.every(w => w[0] != l || done[w])) classes += ' top-button-done';
                        return (<button key={l} value={l} onClick={this.setLetters} className={classes}>
                            {l}
                        </button>);
                    })}
                </div>
                <div id='mid-buttons'>
                    {game.seconds.filter(ls => ls[0] == letters[0]).map(ls => {
                        let classes = 'mid-button';
                        if(ls == letters) classes += ' mid-button-selected';
                        if(game.words.every(w => !w.startsWith(ls) || done[w])) classes += ' mid-button-done';
                        return (<button key={ls} value={ls} onClick={this.setLetters} className={classes}>
                            {ls}
                        </button>);
                    })}
                </div>
                <div id='clues'>
                    <ul>
                        {items}
                    </ul>
                </div>
            </div>
        );
    }
}

//// TESTING ////

// const game = { data: {"today":{"expiration":1656918000,"displayWeekday":"Sunday","displayDate":"July 3, 2022","printDate":"2022-07-03","centerLetter":"b","outerLetters":["a","n","o","t","u","y"],"validLetters":["b","a","n","o","t","u","y"],"pangrams":["buoyant"],"answers":["buoyant","abbot","about","abut","attaboy","baba","baboon","baby","banana","banyan","baobab","batboy","baton","batty","bayou","boat","boba","bonbon","bonny","bonobo","bony","boob","booboo","booby","boon","boot","booty","botany","bounty","bout","bubba","bunny","bunt","buoy","butt","button","buyout","nabob","nanobot","noob","nubby","tabby","taboo","tuba","tubby","unban","unbutton"],"id":13081,"freeExpiration":0,"editor":"Sam Ezersky"},"yesterday":{"expiration":1656831600,"displayWeekday":"Saturday","displayDate":"July 2, 2022","printDate":"2022-07-02","centerLetter":"p","outerLetters":["a","c","i","l","o","t"],"validLetters":["p","a","c","i","l","o","t"],"pangrams":["apolitical","capitol","occipital","optical","political","topical"],"answers":["apolitical","capitol","occipital","optical","political","topical","alcopop","alpaca","appall","atop","capital","capo","catalpa","clap","clip","clop","coop","coopt","copilot","laptop","lipo","lollipop","lollop","loop","octopi","opal","optic","pact","pail","palapa","palatal","palatial","pall","palp","papa","papal","papilla","patio","pica","piccata","piccolo","picot","pill","pilot","pipit","pita","pitapat","plait","plat","plop","plot","polio","politic","politico","poll","polo","pool","poop","poppa","potato","tapa","tapioca","tilapia","tiptop","topcoat","topic"],"id":20028,"freeExpiration":0,"editor":"Sam Ezersky"}}};
// game.special = game.data.today.centerLetter;
// game.words = game.data.today.answers.sort((a,b) =>
//     a.slice(0,2) == b.slice(0,2) ? a.length - b.length : a < b ? -1 : 1);
// game.firsts = unique(game.words.map(w => w.slice(0,1)));
// game.seconds = unique(game.words.map(w => w.slice(0,2)));
// root.render(<App game={game} />);