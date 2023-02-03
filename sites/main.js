const q = document.querySelector.bind(document);
let byProgram = false, editor, outputArea;
let timerId;

function reformat(event, ui) {
  const input = editor.getValue();
  const indentDepth = q('#indent-depth').value;
  try {
    toastr.clear();
    outputArea.setValue(spfmt(input, indentDepth));
  } catch (err) {
    toastr.remove();
    outputArea.setValue('');
    let title = 'SyntaxError';
    if (err.location) {
      const startLine = err.location.start.line;
      const endLine = err.location.end.line;
      const startCol = err.location.start.column;
      const endCol = err.location.end.column;
      if (startLine == endLine) {
        title += ` line:${startLine}(col:${startCol}-${endCol})\n`;
      } else {
        title += ` line:${startLine}(col:${startCol})-${endLine}(col:${endCol})\n`;
      }
      // outputArea.setSelection({line: startLine-1, ch: startCol-1}, {line: endLine-1, ch: endCol-1});
    }
    toastr.options = {
      timeOut: 0,
      extendedTimeOut: 0,
      closeButton: true,
      preventDuplicates: true
    }
    toastr.error(err.message || '', title);
  }
}

function onChanged(delta) {
  if (!byProgram) {
    clearTimeout(timerId);
    timerId = setTimeout(reformat, 500);
  } else {
    byProgram = false;
  }
}

editor = CodeMirror.fromTextArea(q('#input-sparql'), {
  lineNumbers: true,
  viewportMargin: Infinity,
  lineWrapping: true
});

outputArea = CodeMirror.fromTextArea(q('#formatted-sparql'), {
  lineNumbers: true,
  viewportMargin: Infinity,
  lineWrapping: true,
  readOnly: true
});

editor.setSize('100%', '100%');

outputArea.setSize('100%', '100%');

editor.on('change', onChanged);

q('#indent-depth').addEventListener('change', onChanged);

q('#query-select').addEventListener('change', (event) => {
  if (event.target.value === '') {
    editor.setValue('SELECT * WHERE { ?s ?p ?o. } LIMIT 10');
  } else {
    let url = `https://raw.githubusercontent.com/sparqling/sparql-formatter/main/sparql11-query/${event.target.value}`;
    axios.get(url).then((response) => {
      editor.setValue(response.data);
    });
  }
});

q('#copy-button').addEventListener('click', () => {
  navigator.clipboard.writeText(outputArea.getValue());
});

document.addEventListener('DOMContentLoaded', function (event) {
  let url = `https://api.github.com/repos/sparqling/sparql-formatter/contents/sparql11-query`;
  axios.get(url).then((response) => {
    const selectNode = q('#query-select');
    selectNode.innerHTML = '';

    let firstOption = document.createElement('option');
    firstOption.innerText = '';
    selectNode.appendChild(firstOption);

    for (let object of response.data) {
      if (object.name.endsWith('.rq')) {
        let option = document.createElement('option');
        option.innerText = object.name;
        selectNode.appendChild(option);
      }
    }
  });
});
