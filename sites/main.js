const q = document.querySelector.bind(document);
let byProgram = false, editor, outputArea;
let timerId;

function reformat(event, ui) {
  try{
    outputArea.setValue(spfmt.reformat(editor.getValue(), q('#indent-depth-input').value ));
  } catch(e) {
    console.log(e);
    toastr.error('', 'SyntaxError', {preventDuplicates: true})
  }
}

function  onChanged(delta) {
  if (!byProgram) {
    clearTimeout(timerId);
    timerId = setTimeout(reformat, 500);
  } else {
    byProgram = false;
  }
}

editor = CodeMirror.fromTextArea(q('#sparql-input'), {
  lineNumbers: true,
  viewportMargin: Infinity,
  lineWrapping: true,
});

outputArea = CodeMirror.fromTextArea(q('#formatted-input'), {
  lineNumbers: true,
  viewportMargin: Infinity,
  lineWrapping: true,
  readOnly: true
});

editor.setSize('100%', '100%');

outputArea.setSize('100%', '100%');

editor.on('change', onChanged);


q('#indent-depth-input').addEventListener('change', onChanged);

q('#query-select').addEventListener('change', (event) => {
  if (event.target.value === '') {
    editor.setValue('SELECT * WHERE { ?s ?p ?o. } LIMIT 10');
  } else {
    let url = `https://raw.githubusercontent.com/sparqling/sparql-formatter/main/sparql11-query/${event.target.value}`;
    axios.get(url).then((response) => {
      editor.setValue(response.data);
    });
  }
})


q('#copy-button').addEventListener('click', () => {
  navigator.clipboard.writeText(outputArea.getValue());
  toastr.success('', 'Copied to clipboard', {preventDuplicates: true, fadeOut: 200, timeOut: 2000})
});

document.addEventListener("DOMContentLoaded", function(event) {
  let url = `https://api.github.com/repos/sparqling/sparql-formatter/contents/sparql11-query`;
  axios.get(url).then((response) => {

    const selectNode = q("#query-select");
    selectNode.innerHTML = '';

    let firstOption = document.createElement("option");
    firstOption.innerText = '';
    selectNode.appendChild(firstOption);

    for(let object of response.data) {
      if(object.name.endsWith('.rq')) {
        let option = document.createElement("option");
        option.innerText = object.name;
        selectNode.appendChild(option);
      }
    }
  });
});
