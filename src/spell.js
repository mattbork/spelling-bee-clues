const reject_kinds = [
	['slang', 'derogatory', 'obsolete', 'archaic', 'dated'], // + ['colloquial']
	['derogatory', 'obsolete', 'archaic', 'dated'],
	['obsolete', 'archaic', 'dated'],
	[]
]

function clip_plural(word) {
	return word.endsWith('s') ? word.slice(0, -1) : word;
}

function word_reuse(a, b) {
	return (a.length >= 3 && b.length >= 3) &&
		(a.startsWith(b) || a.endsWith(b) || b.startsWith(a) || b.endsWith(a));
}

function filtered_text(def, start = 0) {
	for(let k = start; k < def.children.length; k++) {
		const elm = def.children[k];
		if(elm.matches('ul, ol, dl, span.HQToggle, sup')) {
			elm.remove();
			k -= 1;
		}
	}
	return def.innerText.trim().toLowerCase().replace(/\s{2,}/, ' ');
}

function blank_word(clue_word, word) {
	const match = clue_word.match(/(.*)\b(\w+?)(s?\b.*)/);
	if(!match || match.length < 4) return clue_word;
	const [_, pre, clue, post] = match;
	if(!word_reuse(clue, word)) return clue_word;
	let blank = '___';
	if(clue.length > word.length) 
		blank = clue.startsWith(word) ?
			('___' + clue.slice(word.length)) : 
			(clue.slice(0, -word.length) + '___');
	return pre + blank + post;
}

/// callback: function(word, clue)
function wiki(callback, word, original = null, prefix = '', reject_level = 0) {
	// console.log("wiki('" + word + "', '" + original + ", '" + prefix + "')");
	fetch("https://en.wiktionary.org/w/api.php?action=parse&prop=text&format=json&origin=*&page=" + word)
	.then(resp => resp.json())
	.then(data => { 
		const text = data.parse.text['*'];
		const doc = (new DOMParser()).parseFromString(text, 'text/html');
		const children = doc.documentElement.children[1].children[0].children;
		let i = 0;
		for(i = 0; i < children.length; i++) {
			const x = children[i];
			if(x.matches('h2') && x.children[0]?.matches('span#English')) break; 
		}
		let all = [];
		let alt = null;
		for(i = i + 1; i < children.length; i++) {
			const x = children[i]; 
			if(x.matches('h2')) break;
			if(x.matches('ol')) {
				for(let def of x.children) {	
					if(def.matches('li')) {
						if(def.children[0]?.matches('span.form-of-definition')) {
							if(alt) continue;
							let a = def.children[0].querySelector('span.form-of-definition-link a');
							alt = { word: a.innerText.trim() };
							a.remove();
							alt.prefix = 'the ' + filtered_text(def) + ' ';
							continue;
						}

						let clue = filtered_text(def);
						if(clue.length == 0) continue;
						if(clue[0] == '(') {
							let end = clue.indexOf(')') + 1;
							let kind = clue.slice(0, end).toLowerCase();
							if(reject_kinds[reject_level].some(x => kind.indexOf(x) >= 0)) continue;
							clue = clue.slice(end).trim();
						}		
						all.push(clue);
					}
				}
			}
		}
		
		// all.sort((a,b) => a.length - b.length);

		// console.log('=> ' + all.length + ' clue(s)');
		let last_ditch = null;
		for(let clue of all) {
			const clue_words = clue.match(/\b(\w+)\b/g);
			if(clue_words.some(x => word_reuse(clip_plural(x), word))) {
				// console.log("=> reject clue '" + clue + "' because of " + clue_words.find(x => word_reuse(x, word)));
				if(!last_ditch) { last_ditch = clue; } continue;
			}
			// console.log("=> accept clue '" + (prefix + clue) + "'");
			// clues[original || word] = prefix + clue;
			callback(original || word, prefix + clue);
			return;
		}
		
		// console.log('=> no good clues, alt = ' + (alt ? alt.word : 'null'));
		if(alt) {
			wiki(callback, alt.word, word, alt.prefix);
			return;
		}

		if(last_ditch) {
			const clue = last_ditch.split(' ').map(x => blank_word(x, word)).join(' ');
			// console.log("=> last ditch clue '" + clue + "'");
			// clues[original || word] = prefix + clue;
			callback(original || word, prefix + clue);
			return;
		}

		// try again, taking more kinds
		if(reject_level + 1 < reject_kinds.length)
			wiki(callback, word, original, prefix, reject_level + 1);
	})
	.catch(err => {
		console.error('wiktionary fetch failed', word, original, prefix, err);
	});
}

export default function get_clues(answers, callback) {
	for(let word of answers) {
		wiki(callback, word);
	}
}
