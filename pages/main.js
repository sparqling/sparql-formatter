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
  // theme: "monokai",
  lineWrapping: true,
});

outputArea = CodeMirror.fromTextArea(q('#formatted-input'), {
  lineNumbers: true,
  viewportMargin: Infinity,
  // theme: "monokai",
  lineWrapping: true,
  readOnly: true
});

editor.setSize('100%', '100%');

outputArea.setSize('100%', '100%');

editor.on('change', onChanged);


q('#indent-depth-input').addEventListener('change', onChanged);

q('#query-select').addEventListener('change', (event) => {
  let url = `https://raw.githubusercontent.com/sparqling/sparql-formatter/main/sparql11-query/${event.target.value}`;
  axios.get(url).then((response) => {
    editor.setValue(response.data);
  });
})
